#!/bin/bash

# ==============================================================================
# SCRIPT: substituidor_final_readme.sh
# DESCRIÇÃO: Atualiza blocos por ID. Se o ID não existir, insere no FINAL.
# ==============================================================================

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
BASE_DIR=$(readlink -f "$SCRIPT_DIR/../..")

# --- CONFIGURAÇÃO DO CONTEÚDO ---

# O Heredoc preserva o título, negritos e quebras de linha exatamente como digitados
read -r -d '' NOVO_CONTEUDO << EOM
---
**Desenvolvido por Francisco Silva (FSilva)**

_Atualizado em: $(date +%d/%m/%Y)_
EOM

# --------------------------------------------

echo "Iniciando processamento em: $BASE_DIR"

# Localiza todos os README.md (ignorando repos/*/*)
find "$BASE_DIR" -path "$BASE_DIR/repos/*/*" -prune -o -name "README.md" -type f -print | while read -r ARQUIVO_MD; do

    # Marcadores invisíveis (Comentários HTML)
    ID_START="<!-- START_ID:bloco_final -->"
    ID_END="<!-- END_ID:bloco_final -->"
    
    # Monta o bloco completo com os IDs e as quebras de linha
    export BLOCO_COMPLETO="$ID_START
$NOVO_CONTEUDO
$ID_END"

    # 1. Verifica se o marcador de início já existe no arquivo
    if grep -q "$ID_START" "$ARQUIVO_MD"; then
        # Se existe, o Perl substitui tudo o que estiver entre os IDs
        # A flag /s permite que o ponto (.) capture quebras de linha
        perl -i -0777 -pe "s/$ID_START.*?$ID_END/\$ENV{BLOCO_COMPLETO}/gs" "$ARQUIVO_MD"
        echo "Atualizado (Substituído): $ARQUIVO_MD"
    else
        # 2. Se não existe, anexa ao FINAL do arquivo
        # Adiciona uma linha em branco antes para não colar no texto anterior
        echo -e "\n$BLOCO_COMPLETO" >> "$ARQUIVO_MD"
        echo "Adicionado ao FINAL: $ARQUIVO_MD"
    fi

done

echo "Processo concluído!"
