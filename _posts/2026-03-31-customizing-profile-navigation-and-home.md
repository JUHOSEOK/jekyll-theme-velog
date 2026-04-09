---
title: "프로필, 탭, 홈 화면을 테마 설정으로 커스터마이징하기"
description: "브랜드 문구와 탭 노출 여부, 헤더 버튼, 홈 검색 문구, GitHub 동기화 옵션을 어디서 조절하는지 체계적으로 정리합니다."
date: 2026-03-31 09:00:00 +0900
updated_at: 2026-04-03 12:40:00 +0900
thumbnail: /assets/images/posts/customization-cover.png
series: theme-setup
tags:
  - Theme Config
  - Navigation
  - Profile
  - Customization
---

이 테마는 HTML을 바로 열기 전에 `_config.yml`, `_data/theme.yml`, `_data/profile.yml`, `_data/series.yml` 네 군데만 먼저 보면 구조를 거의 파악할 수 있습니다. 커스터마이징도 이 네 파일에서 대부분 끝납니다.

## 어떤 파일을 어디에 쓰는가

### `_config.yml`

사이트 자체의 주소와 메타데이터를 담당합니다.

- 블로그 제목
- 설명
- `url`
- `baseurl`
- Google Analytics, Algolia, Giscus 같은 외부 연동

이 파일은 “사이트 레벨 설정”이라고 생각하면 됩니다.

### `_data/theme.yml`

화면에 보이는 UI 옵션과 문구를 담당합니다.

- 헤더 GitHub / RSS / 다크모드 토글 노출
- `글 / 시리즈 / 소개` 탭 노출 여부
- 홈 검색 placeholder
- 홈의 기본 로딩 개수
- GitHub 프로필 동기화 사용 여부

이 파일은 “테마 레벨 설정”입니다.

### `_data/profile.yml`

GitHub 연동이 없을 때 보여줄 기본 프로필을 정의합니다.

- 표시 이름
- 소개 문구
- 기본 아바타
- 기본 GitHub 링크

즉, 동기화 실패 상황까지 포함해 화면이 비어 보이지 않도록 받쳐 주는 파일입니다.

### `_data/series.yml`

시리즈 키와 표시용 제목, 설명을 분리합니다.

```yml
theme-overview:
  title: 테마 소개와 구조
  description: 홈 구성, 글 목록, 시리즈 카드처럼 테마의 핵심 화면 구성을 빠르게 훑습니다.
```

글 front matter에는 짧은 키만 넣고, 실제 카드에 보일 문구는 이 파일에서 관리하는 방식이 더 유지보수에 좋습니다.

## 가장 많이 바꾸는 옵션 예시

소개 탭을 숨기고, 헤더에서 RSS는 숨기고, GitHub 프로필 동기화만 유지하고 싶다면 아래처럼 바꿀 수 있습니다.

```yml
header:
  show_github_link: true
  show_rss_link: false
  show_theme_toggle: true

tabs:
  show_about: false

profile:
  github_sync:
    enabled: true
```

## 브랜드만 빠르게 바꾸는 체크리스트

새 프로젝트에 이 테마를 가져갔다면 아래 순서가 가장 효율적입니다.

1. `_config.yml`의 `title`, `description`, `url`, `baseurl` 수정
2. `_data/profile.yml`의 기본 이름과 소개 수정
3. `_data/theme.yml`의 헤더 버튼과 탭 옵션 조정
4. `_data/series.yml`에 실제 시리즈 제목 입력
5. `_posts`의 샘플 글을 유지하거나 교체

## 언제 HTML/CSS를 열어야 하나

대부분의 커스터마이징은 데이터 파일에서 끝나지만, 아래 경우에는 템플릿이나 CSS를 열어야 합니다.

- 카드 간격이나 폰트 크기를 바꾸고 싶을 때
- 태그/시리즈 레이아웃 구조를 바꾸고 싶을 때
- 헤더 아이콘 모양 자체를 교체하고 싶을 때

즉, 텍스트와 옵션은 데이터 파일, 구조와 스타일은 레이아웃/CSS라는 기준으로 보면 복잡도가 많이 내려갑니다.
