---
title: "로컬에서 테마를 설치하고 미리보기하는 가장 빠른 방법"
description: "Ruby 의존성 설치부터 GitHub 연동 데이터 동기화, 로컬 미리보기와 흔한 오류 대응까지 한 번에 정리합니다."
date: 2026-04-01 09:00:00 +0900
updated_at: 2026-04-03 12:40:00 +0900
thumbnail: /assets/images/posts/local-setup-cover.png
series: theme-setup
tags:
  - Quick Start
  - Local Preview
  - Ruby
  - Jekyll
---

처음 실행할 때는 명령 자체보다 “어떤 단계는 선택 사항이고, 어떤 단계는 필수인지”를 구분하는 것이 중요합니다. 이 테마는 GitHub 연동이 없어도 열리지만, Ruby 의존성과 `baseurl`만큼은 정확히 맞아야 합니다.

## 준비물

로컬 미리보기를 위해 필요한 것은 아래 정도입니다.

- Ruby와 Bundler
- Git
- 선택 사항: `gh auth login` 또는 GitHub 토큰

GitHub 연동이 없더라도 화면은 정상으로 열립니다. 다만 이 경우 프로필과 잔디 그래프는 샘플 상태를 유지합니다.

## 가장 짧은 실행 순서

```bash
BUNDLE_FORCE_RUBY_PLATFORM=true bundle install
ruby scripts/fetch_github_contributions.rb
BUNDLE_FORCE_RUBY_PLATFORM=true bundle exec jekyll serve
```

두 번째 줄은 선택입니다. GitHub 프로필과 기여 그래프를 연결하지 않을 거라면 생략해도 됩니다.

## 미리보기 주소

현재 저장소 이름 기준 기본 주소는 다음입니다.

```text
http://127.0.0.1:4000/
```

커스텀 도메인을 쓰고 `baseurl`을 비워 둔 상태라면 로컬 미리보기 주소도 루트(`/`)로 열립니다. 프로젝트 페이지를 쓸 때만 저장소 이름에 맞는 `baseurl`이 필요합니다.

## GitHub 동기화 없이 실행하는 경우

토큰이 아직 없거나 GitHub 연동을 나중에 붙일 생각이라면 이렇게 실행해도 됩니다.

```bash
BUNDLE_FORCE_RUBY_PLATFORM=true bundle install
BUNDLE_FORCE_RUBY_PLATFORM=true bundle exec jekyll serve
```

이 경우 화면은 아래처럼 동작합니다.

- 프로필 이름과 소개는 `_data/profile.yml`의 샘플 값 사용
- 브라우저 탭 아이콘과 헤더 이미지는 기본 프로필 이미지 사용
- 잔디 그래프는 캐시가 없으면 비어 있거나 마지막 캐시 상태를 사용

## 처음 실행할 때 자주 걸리는 문제

### gem 설치가 실패하는 경우

Apple Silicon이나 특정 네이티브 gem 환경에서는 Ruby 플랫폼 관련 오류가 날 수 있습니다. 그래서 이 저장소는 예시 명령에 `BUNDLE_FORCE_RUBY_PLATFORM=true`를 기본으로 넣어 두었습니다.

### 잔디 그래프가 비어 보이는 경우

아래 중 하나만 준비되어 있으면 됩니다.

- `GITHUB_GRAPHQL_TOKEN`
- `GITHUB_TOKEN`
- `gh auth login`

셋 다 없으면 스크립트는 공개 GitHub 데이터를 가져오지 못합니다.

### 주소는 열리는데 스타일이 이상한 경우

가장 먼저 `_config.yml`의 `baseurl`과 실제 저장소 이름이 같은지 확인하세요. 프로젝트 페이지는 저장소 이름이 곧 URL 경로가 되기 때문에, 이 값이 어긋나면 CSS와 JS 경로가 같이 틀어집니다.

## 추천 로컬 워크플로

처음 테마를 가져간 뒤에는 아래 흐름이 편합니다.

1. `bundle install`
2. `_config.yml`에서 `title`, `url`, `baseurl` 수정
3. `_data/profile.yml` 수정
4. `jekyll serve`로 화면 확인
5. 그 다음에 GitHub 동기화와 배포 설정 진행

이 순서대로 가면 “배포까지는 됐는데 주소가 꼬여 있는 상태”를 훨씬 덜 만나게 됩니다.
