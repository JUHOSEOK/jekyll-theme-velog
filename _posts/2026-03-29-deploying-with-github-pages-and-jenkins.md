---
title: "GitHub Pages와 Jenkins로 테마를 배포하는 방법"
description: "프로젝트 페이지 기준으로 빌드 결과를 gh-pages 브랜치에 배포하는 흐름과 저장소 이름 변경 시 주의할 점까지 정리합니다."
date: 2026-03-29 09:00:00 +0900
updated_at: 2026-04-03 12:40:00 +0900
thumbnail: /assets/images/posts/deployment-guide-cover.png
series: theme-operations
tags:
  - GitHub Pages
  - Jenkins
  - Deployment
  - Open Source
---

이 테마는 `main`에서 Jekyll을 빌드하고, 결과를 `gh-pages` 브랜치로 배포하는 구조를 기본값으로 둡니다. GitHub Pages 프로젝트 페이지 기준으로 가장 단순하고 재현하기 쉬운 배포 방식입니다.

## 기본 배포 흐름

파이프라인이 하는 일은 아래 네 단계입니다.

1. gem 설치
2. GitHub 프로필과 기여 그래프 캐시 동기화
3. `jekyll build`
4. `_site/` 내용을 `gh-pages` 브랜치로 푸시

Jenkins를 쓰지 않더라도, 핵심은 “정적 결과물을 어디에 배포할지”입니다. CI가 GitHub Actions든 Jenkins든 결과만 `gh-pages`에 올리면 구조는 같습니다.

## GitHub Pages 설정

프로젝트 페이지를 쓰는 경우 GitHub 저장소 설정에서 아래 두 가지를 맞춰야 합니다.

- Pages source: `gh-pages` 브랜치
- Folder: `/ (root)`

이 설정이 빠지면 브랜치는 갱신돼도 실제 사이트는 열리지 않습니다.

## 저장소 이름과 baseurl

가장 자주 틀리는 부분은 `baseurl`입니다. 프로젝트 페이지는 저장소 이름이 URL 경로가 되므로, 저장소를 `jekyll-theme-velog`로 바꿨다면 `_config.yml`도 이렇게 맞아야 합니다.

```yml
url: "https://blog.woonyong.org"
baseurl: ""
```

커스텀 도메인을 쓴다면 `baseurl`은 보통 비워 두는 편이 맞습니다. 반대로 `github.io/저장소명` 프로젝트 페이지를 그대로 쓸 때는 저장소 이름을 `baseurl`로 넣어야 합니다.

## Jenkins에서 필요한 것

이 저장소의 `Jenkinsfile`을 그대로 쓰려면 아래 자격 증명이 필요합니다.

- `github-pages`
  - username: GitHub 사용자명
  - password: GitHub Personal Access Token

그리고 Jenkins 에이전트에는 Ruby와 Bundler가 있어야 합니다.

## 수동 배포로 검증하는 방법

자동화 전에 먼저 로컬 빌드만 검증하고 싶다면 아래 명령으로 충분합니다.

```bash
BUNDLE_FORCE_RUBY_PLATFORM=true bundle exec jekyll build
```

그 다음 `_site` 내용이 올바른지 확인한 뒤, 원하는 배포 도구로 `gh-pages`에 올리면 됩니다.

## 배포 후 확인 체크리스트

배포가 끝났다면 아래 네 가지를 바로 보는 편이 좋습니다.

1. Pages 주소가 200 응답인지
2. `index.html`이 올바른 `baseurl`을 쓰는지
3. `feed.xml`과 썸네일 이미지가 정상 응답인지
4. 홈과 시리즈 페이지가 같은 경로 체계를 쓰는지

정적 블로그는 에러 로그보다 “잘못된 링크 경로”가 더 흔한 장애 원인이기 때문에, 이 체크리스트만으로도 대부분의 배포 문제를 초기에 잡을 수 있습니다.
