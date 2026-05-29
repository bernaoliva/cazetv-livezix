#!/usr/bin/env ruby
# Adiciona os 5 arquivos Swift da pasta Moblin/LiveZix/ ao project.pbxproj
# como membros do target "Moblin". Roda no Codemagic ANTES do xcodebuild.
#
# Sem isso, os arquivos novos LiveZix*.swift não compilam (Xcode não os vê).
# Idempotente: detecta se já estão adicionados e não duplica.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../Moblin.xcodeproj', __dir__)
TARGET_NAME = 'Moblin'
LIVEZIX_GROUP_NAME = 'LiveZix'
LIVEZIX_DIR = File.expand_path('../Moblin/LiveZix', __dir__)

puts "==> Abrindo projeto #{PROJECT_PATH}"
project = Xcodeproj::Project.open(PROJECT_PATH)

target = project.targets.find { |t| t.name == TARGET_NAME }
abort "ERRO: target '#{TARGET_NAME}' não encontrado!" unless target

# Acha o grupo "Moblin" (raiz do app no Project Navigator)
moblin_group = project.main_group.children.find { |g| g.respond_to?(:name) && g.path == 'Moblin' }
unless moblin_group
  moblin_group = project.main_group.children.find { |g| g.respond_to?(:name) && (g.name == 'Moblin' || g.display_name == 'Moblin') }
end
abort "ERRO: grupo 'Moblin' não encontrado no Project Navigator!" unless moblin_group

puts "==> Grupo raiz: #{moblin_group.display_name}"

# Cria (ou reusa) sub-grupo LiveZix
livezix_group = moblin_group.children.find { |g| g.respond_to?(:name) && (g.name == LIVEZIX_GROUP_NAME || g.path == LIVEZIX_GROUP_NAME) }
if livezix_group.nil?
  livezix_group = moblin_group.new_group(LIVEZIX_GROUP_NAME, 'LiveZix')
  puts "==> Grupo 'LiveZix' criado"
else
  puts "==> Grupo 'LiveZix' já existe"
end

# Lista de arquivos pra adicionar
swift_files = Dir.glob(File.join(LIVEZIX_DIR, '*.swift')).sort
abort "ERRO: nenhum arquivo .swift encontrado em #{LIVEZIX_DIR}" if swift_files.empty?

# Lista arquivos JÁ adicionados ao target Sources build phase
existing_paths = target.source_build_phase.files.map do |bf|
  bf.file_ref && bf.file_ref.real_path.to_s
end.compact

added = 0
swift_files.each do |full_path|
  filename = File.basename(full_path)

  # Verifica se já está no target
  if existing_paths.any? { |p| p.end_with?(File.join('LiveZix', filename)) || p == full_path }
    puts "  - já adicionado: #{filename}"
    next
  end

  # Cria file ref dentro do grupo LiveZix
  file_ref = livezix_group.children.find { |c| c.respond_to?(:path) && c.path == filename }
  if file_ref.nil?
    file_ref = livezix_group.new_reference(filename)
  end

  # Adiciona ao target Sources
  target.add_file_references([file_ref])
  added += 1
  puts "  + adicionado: #{filename}"
end

if added > 0
  project.save
  puts "==> Projeto salvo. #{added} arquivo(s) adicionado(s) ao target #{TARGET_NAME}."
else
  puts "==> Nenhuma mudança necessária — todos os arquivos já estavam adicionados."
end
