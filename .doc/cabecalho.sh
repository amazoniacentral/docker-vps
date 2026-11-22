#!/bin/bash

# ==============================================================================
# SCRIPT: substituidor_topo_readme.sh
# DESCRIÇÃO: Atualiza blocos por ID. Se o ID não existir, insere no TOPO.
# ==============================================================================

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
BASE_DIR=$(readlink -f "$SCRIPT_DIR/../..")

# --- CONFIGURAÇÃO DO CONTEÚDO ---

# Usando Heredoc para manter as quebras de linha e a formatação
read -r -d '' NOVO_CONTEUDO << EOM
# FSilva Cloud
*Infraestrutura de Alta Disponibilidade e Orquestração de Containers*

_Uma estrutura híbrida para garantir que seus aplicativos Docker estejam acessíveis de forma segura e eficiente, adaptando-se a diferentes cenários de rede._
EOM

# --------------------------------------------

echo "Iniciando processamento em: $BASE_DIR"

find "$BASE_DIR" -path "$BASE_DIR/repos/*/*" -prune -o -name "README.md" -type f -print | while read -r ARQUIVO_MD; do

    ID_START="<!-- START_ID:cabecalho -->"
    ID_END="<!-- END_ID:cabecalho -->"
    
    # Monta o bloco final que será inserido
    export BLOCO_COMPLETO="$ID_START
$NOVO_CONTEUDO
$ID_END"

    # 1. Verifica se o marcador de início já existe no arquivo
    if grep -q "$ID_START" "$ARQUIVO_MD"; then
        # Se existe, substitui o bloco existente (inclusive as quebras de linha entre os IDs)
        perl -i -0777 -pe "s/$ID_START.*?$ID_END/\$ENV{BLOCO_COMPLETO}/gs" "$ARQUIVO_MD"
        echo "Atualizado (ID encontrado): $ARQUIVO_MD"
    else
        # 2. Se não existe, insere no TOPO do arquivo
        # Criamos um arquivo temporário para garantir a integridade
        TEMP_FILE=$(mktemp)
        {
            echo "$BLOCO_COMPLETO"
            echo "" # Linha em branco de separação
            cat "$ARQUIVO_MD"
        } > "$TEMP_FILE"
        
        mv "$TEMP_FILE" "$ARQUIVO_MD"
        echo "Adicionado ao TOPO (ID não encontrado): $ARQUIVO_MD"
    fi

done

echo "Processo concluído!"
