#!/bin/bash

# ==============================================================================
# SCRIPT: atualizar_readme_com_id.sh
# DESCRIÇÃO: Atualiza blocos de código no README.md usando IDs baseados no nome
#            dos arquivos de origem. Suporta arquivos ocultos como .env.example.
# ==============================================================================

# Definição das bases de diretório
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
BASE_DIR=$(readlink -f "$SCRIPT_DIR/../..")

# Configuração de diretório temporário
TEMP_DIR="${TMPDIR:-/tmp}"
if [ ! -d "$TEMP_DIR" ]; then TEMP_DIR="."; fi

echo "Iniciando atualização inteligente em: $BASE_DIR"

# 1. Localiza os arquivos de origem
find "$BASE_DIR" -path "$BASE_DIR/repos/*/*" -prune -o \( -name ".env.example" -o -name "*.json" -o -name "*.txt" -o -name "*.cs" -o -name "*.py" -o -name "*.sh" -o -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.yml" -o -name "*.yaml" \) -type f -print | while read -r CAMINHO_ORIGEM; do
    
    DIR_ATUAL=$(dirname "$CAMINHO_ORIGEM")
    ARQUIVO_MD="$DIR_ATUAL/README.md"
    NOME_ARQUIVO=$(basename "$CAMINHO_ORIGEM")

    # 2. Lógica de ID ÚNICO corrigida
    if [[ "$NOME_ARQUIVO" == .* ]]; then
        # Para arquivos ocultos (ex: .env.example), o ID será o nome completo
        ID_UNICO="$NOME_ARQUIVO"
    else
        # Para arquivos normais, remove a extensão (ex: script.sh -> script)
        ID_UNICO="${NOME_ARQUIVO%.*}"
    fi

    # 3. Define a LINGUAGEM para o Syntax Highlighting
    case "$NOME_ARQUIVO" in
        ".env"*)         LANG=".env" ;;
        *.json)          LANG="json" ;;
        *.sh)            LANG="bash" ;;
        *.txt)           LANG="text" ;;
        *.cs)            LANG="csharp" ;;
        *.py)            LANG="python" ;;
        *.js)            LANG="javascript" ;;
        *.jsx)           LANG="jsx" ;;
        *.ts)            LANG="typescript" ;;
        *.tsx)           LANG="tsx" ;;
        *.go)            LANG="go" ;;
        *.yml|*.yaml)    LANG="yaml" ;;
        *.html)          LANG="html" ;;
        *.css)           LANG="css" ;;
        *.sql)           LANG="sql" ;;
        *.dockerfile|Dockerfile*) LANG="dockerfile" ;;
        *)               LANG="text" ;;
    esac

    # 4. Verifica se o README.md existe no diretório
    if [ -f "$ARQUIVO_MD" ]; then
        
        # Define a tag de busca exata
        BUSCA_TAG="$LANG <!-- ID: $ID_UNICO -->"
        
        # Prepara o conteúdo para injeção
        ARQUIVO_TEMP=$(mktemp "$TEMP_DIR/id_subst_XXXXXX.txt")
        cat "$CAMINHO_ORIGEM" > "$ARQUIVO_TEMP"
        
        # Exporta variáveis para o Perl
        export CONTEUDO_ID=$(cat "$ARQUIVO_TEMP")
        export TAG_COMPLETA="$BUSCA_TAG"
        
        # 5. Executa a substituição
        # O uso de \Q...\E no Perl garante que pontos (.) sejam tratados como texto literal e não como regex
        perl -i -0777 -pe 's/```\Q$ENV{TAG_COMPLETA}\E.*?```/```$ENV{TAG_COMPLETA}\n$ENV{CONTEUDO_ID}\n```/gs' "$ARQUIVO_MD"
        
        rm -f "$ARQUIVO_TEMP"
        
        echo "OK: Bloco [$LANG] com ID [$ID_UNICO] atualizado em $ARQUIVO_MD"
    fi
done

echo "Processo concluído com sucesso!"
