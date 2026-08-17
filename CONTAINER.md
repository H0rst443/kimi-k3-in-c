# Running Kimi K3 with Portainer

This stack builds a small CPU-only image containing the `k3` executable plus the
repository's `scripts/` and `tools/`. Model weights are never copied into the image.

## Host storage

The stack uses these read-only bind mounts on the host:

| Host path | Container path | Expected content |
|---|---|---|
| `/mnt/nvme/k3model` | `/models/checkpoint` | 1.56 TB checkpoint, config, and tokenizer files |
| `/mnt/nvme/k3trunk` | `/models/trunk` | 109 GB packed trunk (`trunk.bin` and `trunk.json`) |

Both host directories must be on fast local NVMe storage whose filesystem supports
`O_DIRECT`. Do not replace these binds with Docker named volumes, network storage, or
paths inside Docker's overlay storage. The container user must be able to read all model
files.

## RAM configuration

This 32 GB host is configured for the `laptop` preset. Compose limits the container to
12 GB of RAM and sets `memory-swap` to the same value, which disables container swap.
The preset's measured peak RSS is approximately 8.2 GB, leaving headroom for runtime
variation. The `desktop` preset has a measured peak of approximately 31.9 GB and is not
safe on this host while the host and Portainer also need memory.

## Huge pages and direct I/O

The engine allocates its streaming arenas on 2 MB boundaries and calls
`madvise(MADV_HUGEPAGE)`. It therefore uses Linux transparent huge pages (THP), not the
explicit hugetlb pool under `/dev/hugepages`. Configure the Docker host for THP's
`madvise` mode before deploying:

```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
echo madvise | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
grep -E 'AnonHugePages|Hugepagesize' /proc/meminfo
```

Persist that setting using the host distribution's boot or systemd configuration after
validating it. Docker's normal seccomp profile permits `madvise`, and THP is charged to
the container's regular memory cgroup. No capability, hugetlb mount, memlock override,
or privileged mode is required. `O_DIRECT` likewise needs no extra capability when the
NVMe filesystem supports it and the files are readable. The engine falls back to
buffered I/O if the filesystem rejects `O_DIRECT`, so check its startup report rather
than assuming direct I/O is active.

## Portainer workflow

1. In Portainer, create a stack from this Git repository and select branch
   `agent/portainer-containerization`.
2. Set `OMP_NUM_THREADS` to the number of CPU threads assigned to this workload.
3. Set exactly one prompt variable: `K3_PROMPT`, `K3_PROMPT_FILE`, or `K3_IDS`.
4. Optionally set `K3_GEN` (default `8`) and `HF_TOKEN`. Keep `HF_TOKEN` in Portainer's
   environment or secret handling; never commit it.
5. Deploy the stack. The result is written to the `k3-output` volume as
   `/output/k3_run.json`.

The container exits after one inference run. To use other native CLI options, set the
Portainer service command to those arguments, for example:

```text
--ids 1008,10484,318,15383,387 --gen 8 --incremental --out /output/k3_run.json
```

The entry point supplies the checkpoint, trunk, and tokenizer paths for command
overrides. Prefix a command with `k3` only when you want complete control over every
argument.
