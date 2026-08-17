#!/bin/sh
set -eu

if [ "${1:-}" = "k3" ]; then
    shift
    exec k3 "$@"
fi

if [ "$#" -gt 0 ]; then
    exec k3 "$K3_MODEL_DIR" --trunk "$K3_TRUNK_DIR" --tok "$K3_TOKENIZER_DIR" "$@"
fi

for required_dir in "$K3_MODEL_DIR" "$K3_TRUNK_DIR" "$K3_TOKENIZER_DIR"; do
    if [ ! -d "$required_dir" ]; then
        echo "required directory is not mounted: $required_dir" >&2
        exit 2
    fi
done

set -- "$K3_MODEL_DIR" \
    --trunk "$K3_TRUNK_DIR" \
    --tok "$K3_TOKENIZER_DIR" \
    --preset "$K3_PRESET" \
    --gen "$K3_GEN" \
    --out "$K3_OUT"

if [ "$K3_INCREMENTAL" = "1" ]; then
    set -- "$@" --incremental
fi

prompt_count=0
if [ -n "${K3_PROMPT:-}" ]; then
    set -- "$@" --prompt "$K3_PROMPT"
    prompt_count=$((prompt_count + 1))
fi
if [ -n "${K3_PROMPT_FILE:-}" ]; then
    set -- "$@" --prompt-file "$K3_PROMPT_FILE"
    prompt_count=$((prompt_count + 1))
fi
if [ -n "${K3_IDS:-}" ]; then
    set -- "$@" --ids "$K3_IDS"
    prompt_count=$((prompt_count + 1))
fi

if [ "$prompt_count" -ne 1 ]; then
    echo "set exactly one of K3_PROMPT, K3_PROMPT_FILE, or K3_IDS" >&2
    echo "alternatively, set a Portainer command containing k3 CLI arguments" >&2
    exit 2
fi

exec k3 "$@"
