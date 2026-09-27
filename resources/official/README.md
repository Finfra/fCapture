---
title: Official Build Components
description: fCapture 공식 빌드에만 들어가는 브랜드 자산 — Apache-2.0 대상 아님 (Issue30)
date: 2026.09.27
---

# Official Build Components

The files in this folder are **Official Build Components** as defined in
[DISTRIBUTION-TERMS.md](../../DISTRIBUTION-TERMS.md) §1(b). They are **not** licensed under the
Apache License (see [NOTICE](../../NOTICE)) and are included only in Official Builds.

| File         | Embedded as (Mach-O section) | Visible where                         |
| :----------- | :--------------------------- | :------------------------------------ |
| `banner.txt` | `__TEXT,__fc_banner`         | `fcapture --version` (lines 2 and on) |
| `icon.png`   | `__TEXT,__fc_icon`           | — (brand asset carried in the binary) |

* Only `deploy-brew.sh` links these files into the binary (`-sectcreate`). A source build
  (`swift build`, `buildAndTest.sh`) never contains them, so its `--version` prints the version only.
* Forks and source builds must not copy these files into their builds. Use of the name and icon is
  governed by [TRADEMARK.md](../../TRADEMARK.md).
