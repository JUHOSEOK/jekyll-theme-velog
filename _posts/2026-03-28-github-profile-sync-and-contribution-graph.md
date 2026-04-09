---
title: "GitHub 프로필 동기화와 기여 그래프를 붙이는 방법"
description: "GitHub 아이디만 연결하면 이름, 아바타, 링크, 기여 그래프가 홈 화면에 반영되는 흐름과 fallback 규칙을 설명합니다."
date: 2026-03-28 09:00:00 +0900
updated_at: 2026-04-03 12:40:00 +0900
thumbnail: /assets/images/posts/github-sync-cover.png
series: theme-operations
tags:
  - GitHub
  - GraphQL
  - Profile Sync
  - Jekyll Theme
---

이 테마는 GitHub 계정을 연결하면 홈 프로필, 헤더 브랜드 이미지, 브라우저 탭 파비콘, GitHub 링크, 기여 그래프를 자동으로 갱신합니다. 중요한 점은 “연결이 실패해도 화면이 비어 보이지 않게” fallback 구조를 함께 갖고 있다는 것입니다.

## 어떤 데이터를 가져오나

동기화 스크립트는 두 종류의 캐시를 만듭니다.

- `_data/github_profile_cache.json`
  - 이름, 아바타, 프로필 링크, 소개 텍스트
- `_data/github_contributions_cache.json`
  - 최근 1년 기여 캘린더

빌드 시점에는 이 캐시 파일만 읽기 때문에, 브라우저에서 토큰이 노출되지 않습니다.

## 필요한 설정

`_data/theme.yml`에서 아래 두 옵션을 켜면 됩니다.

```yml
hero:
  github_contributions:
    enabled: true
    username: your-github-id

profile:
  github_sync:
    enabled: true
```

`username`이 비어 있으면 `_data/profile.yml`의 GitHub 링크에서 계정 이름을 유추합니다.

## 실행 명령

```bash
ruby scripts/fetch_github_contributions.rb
```

인증은 아래 셋 중 하나면 됩니다.

- `GITHUB_GRAPHQL_TOKEN`
- `GITHUB_TOKEN`
- `gh auth login`

## fallback 규칙

이 테마가 오픈소스 템플릿으로 쓸 만한 이유 중 하나가 바로 이 부분입니다. GitHub 연결이 완벽하지 않아도 화면이 망가지지 않습니다.

- GitHub 아바타가 있으면 아바타를 사용
- GitHub 이름이 있으면 표시 이름을 덮어씀
- GitHub `bio`가 비어 있으면 `_data/profile.yml`의 소개 문구 유지
- 잔디 캐시가 없으면 마지막 캐시 또는 기본 화면 사용

즉, 사용자 입장에서는 “연결되면 자동으로 좋아지고, 연결이 안 돼도 깨지지 않는” 구조입니다.

## Jenkins와 함께 쓸 때

Jenkins 파이프라인에서는 빌드 전에 이 스크립트를 실행하도록 구성해 두었습니다. 그래서 하루 한 번 빌드를 돌리면 GitHub 프로필과 기여 그래프도 함께 최신 상태로 갱신할 수 있습니다.

## 동기화가 안 될 때 확인할 것

1. GitHub username이 실제 계정과 같은지
2. 토큰 또는 `gh auth login`이 준비돼 있는지
3. 캐시 파일이 생성됐는지
4. `_data/profile.yml` fallback 문구만 보이고 있지는 않은지

이 흐름만 이해하면 프로필 동기화는 별도 백엔드 없이도 충분히 안정적으로 운영할 수 있습니다.
