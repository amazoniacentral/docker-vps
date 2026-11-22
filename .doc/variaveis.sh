#!/bin/bash

# ==============================================================================
# SCRIPT: substituidor_final_readme.sh
# DESCRIÇÃO: Atualiza blocos por ID inserindo a estrutura tree no NOVO_CONTEUDO.
# ==============================================================================

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
BASE_DIR=$(readlink -f "$SCRIPT_DIR/../..")

# 1. Verificar se o tree está instalado
if ! command -v tree &> /dev/null; then
    sudo apt update && sudo apt install tree -y
fi

echo "Iniciando processamento em: $BASE_DIR"

# Localiza todos os README.md (ignorando repos/*/*)
find "$BASE_DIR" -path "$BASE_DIR/repos/*/*" -prune -o -name "README.md" -type f -print | while read -r ARQUIVO_MD; do

    # Marcadores invisíveis (Comentários HTML)
    ID_START="<!-- START_ID:bloco_variaveis -->"
    ID_END="<!-- END_ID:bloco_variaveis -->"

    # Definição do diretório temporário para capturar o tree
    TEMP_DIR="${TMPDIR:-/tmp}"
    [ ! -d "$TEMP_DIR" ] && TEMP_DIR="."
    ARQUIVO_TEMP=$(mktemp "$TEMP_DIR/estrutura_XXXXXX.txt")

    # Define o diretório alvo para o tree (pasta onde o README atual está)
    DIRETORIO_ALVO=$(dirname "$ARQUIVO_MD")

    # Gera a estrutura de pastas
    cd "$BASE_DIR"
    # -a: Inclui arquivos ocultos
    # -P '.env.*': Filtra arquivos que começam com '.env.'
    # --prune: Remove diretórios que não contêm os arquivos do padrão
    tree -a -P '.env.*' --prune -I '.git|.github|node_modules|repos/*/*' -L 3 --dirsfirst ".${DIRETORIO_ALVO#$BASE_DIR}" > "$ARQUIVO_TEMP"
    cd "$SCRIPT_DIR"
    
    # Captura o resultado do tree
    ESTRUTURA_TREE=$(cat "$ARQUIVO_TEMP")

    # --- CONFIGURAÇÃO DO CONTEÚDO ---
    read -r -d '' NOVO_CONTEUDO << EOM
\`\`\`bash
$ESTRUTURA_TREE
\`\`\`
EOM
    # --------------------------------------------

    # Monta o bloco completo com os IDs e o conteúdo do tree
    export BLOCO_COMPLETO="$ID_START
$NOVO_CONTEUDO
$ID_END"

    # 1. Verifica se o marcador de início já existe no arquivo
    if grep -q "$ID_START" "$ARQUIVO_MD"; then
        # O Perl substitui tudo o que estiver entre os IDs usando escape para metacaracteres
        perl -i -0777 -pe "s/\Q$ID_START\E.*?\Q$ID_END\E/\$ENV{BLOCO_COMPLETO}/gs" "$ARQUIVO_MD"
        echo "Atualizado (Substituído): $ARQUIVO_MD"
    fi

    # Limpeza do arquivo temporário
    rm -f "$ARQUIVO_TEMP"

done

echo "Processo concluído!"
