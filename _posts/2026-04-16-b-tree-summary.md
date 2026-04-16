---
title: 이진 탐색 트리와 B-Tree / B+Tree 정리
description: 이진 탐색 트리(BST)와 B-Tree, B+Tree의 구조와 삽입, 삭제 흐름을 그림과 함께 정리한다.
date: 2026-04-16 20:00:00 +0900
tags:
  - Data Structure
  - Tree
  - B-Tree
  - B+Tree
  - Database
---

출처: [자료구조 4. Tree](https://velog.io/@thkim0408/%EC%9E%90%EB%A3%8C%EA%B5%AC%EC%A1%B0-4.-Tree)

올려준 초안을 바탕으로, 중복 설명과 오타를 정리하고 그림을 SVG 다이어그램으로 다시 그린 버전이다.

## 1. 먼저, BST부터

### 핵심 용어

- 차수: 한 노드가 가질 수 있는 최대 자식 수
- 서브트리: 특정 노드와 그 자손들로 이루어진 하위 트리
- 리프 노드: 자식이 없는 말단 노드

### BST(Binary Search Tree)의 성질

- 왼쪽 서브트리의 모든 값은 부모보다 작다.
- 오른쪽 서브트리의 모든 값은 부모보다 크다.
- 각 노드는 자식을 최대 2개까지 가진다.

![BST 예시]({{ '/assets/b-tree-summary/01-bst.svg' | relative_url }})

BST는 탐색이 빠르지만, 한 노드가 자식을 2개까지만 가질 수 있다는 한계가 있다. 데이터가 많아지면 높이가 커지고, 디스크/페이지 단위 저장에서는 비효율적일 수 있다.

## 2. 그래서 B-Tree를 쓴다

BST의 한계를 줄이기 위해, 한 노드 안에 여러 개의 key를 저장하고 자식 수도 늘린 구조가 B-Tree다.

![B-Tree 기본 개념]({{ '/assets/b-tree-summary/02-btree-concept.svg' | relative_url }})

한 노드에 key가 2개 있으면 자식은 3개가 된다.  
즉, `key 수 + 1 = 자식 수`가 항상 성립한다.

## 3. 3차 B-Tree의 규칙

여기서는 `M = 3`인 B-Tree를 기준으로 정리한다.

### 기본 규칙

- 최대 자식 수: `M = 3`
- 최대 key 수: `M - 1 = 2`
- 최소 자식 수: `ceil(M / 2) = 2`
- 최소 key 수: `ceil(M / 2) - 1 = 1`

### 예외

- root는 예외적으로 더 적은 key/child를 가질 수 있다.
- 모든 리프 노드는 같은 높이에 있어야 한다.

### 꼭 기억할 성질

- 인터널 노드에 key가 `x`개 있으면 자식은 반드시 `x + 1`개다.
- 리프가 아닌 노드는 최소 2개의 자식을 가져야 한다.
- key는 항상 오름차순으로 정렬되어 있어야 한다.

## 4. B-Tree에서 가질 수 없는 구조

### 1) key 수와 자식 수가 맞지 않는 경우

- key가 1개인데 자식이 3개인 구조는 불가능하다.
- key가 2개인데 자식이 2개뿐인 구조도 불가능하다.

![잘못된 B-Tree 구조 예시]({{ '/assets/b-tree-summary/03-invalid-structure.svg' | relative_url }})

위 구조는 부모 key가 1개인데 자식이 3개라서 규칙 위반이다.

### 2) 자식 구간이 잘못된 경우

부모가 `20 | 40`이면:

- 왼쪽 자식: `20`보다 작은 값
- 가운데 자식: `20`과 `40` 사이 값
- 오른쪽 자식: `40`보다 큰 값

이 구간을 어기면 B-Tree가 아니다.

## 5. 삽입 규칙

- 삽입은 항상 리프 노드에서 시작한다.
- 삽입 후 key 수가 초과되면 노드를 분할한다.
- 가운데 key를 부모로 승진시킨다.
- 부모도 넘치면 같은 과정을 위로 반복한다.

3차 B-Tree에서는 한 노드에 key가 최대 2개까지 들어갈 수 있으므로, 임시로 3개가 되는 순간 분할이 일어난다.

## 6. 3차 B-Tree 삽입 예시

삽입 순서:

`1, 15, 2, 5, 30, 90, 20, 7, 9, 8, 10, 50, 70, 60, 40`

### Step 1. 1, 15 삽입

![삽입 Step 1]({{ '/assets/b-tree-summary/04-step-1.svg' | relative_url }})

루트가 리프이므로 그냥 들어간다.

### Step 2. 2 삽입, 첫 분할

`[1 | 15]`에 `2`를 넣으면 `[1 | 2 | 15]`가 되어 overflow가 발생한다.  
가운데 key `2`를 승진시키면:

![삽입 Step 2]({{ '/assets/b-tree-summary/05-step-2.svg' | relative_url }})

### Step 3. 5, 30 삽입

- `5`는 오른쪽 리프 `[15]`에 들어가 `[5 | 15]`
- `30`을 넣으면 `[5 | 15 | 30]`이 되어 `15`가 부모로 승진

![삽입 Step 3]({{ '/assets/b-tree-summary/06-step-3.svg' | relative_url }})

### Step 4. 90, 20 삽입 후 루트 분할

- `90`은 `[30]`에 들어가 `[30 | 90]`
- `20`을 넣으면 `[20 | 30 | 90]` overflow
- `30`이 부모로 승진하려는데, 부모 `[2 | 15]`도 overflow
- 다시 루트 분할이 일어나 `15`가 새 루트가 된다

![삽입 Step 4]({{ '/assets/b-tree-summary/07-step-4.svg' | relative_url }})

### Step 5. 7, 9 삽입

- `7`은 `[5]`에 들어가 `[5 | 7]`
- `9`를 넣으면 `[5 | 7 | 9]` overflow
- 가운데 `7`이 승진해서 왼쪽 인터널 노드가 `[2 | 7]`이 된다

![삽입 Step 5]({{ '/assets/b-tree-summary/08-step-5.svg' | relative_url }})

### Step 6. 8, 10 삽입 후 왼쪽 서브트리 재분할

- `8`은 `[9]`에 들어가 `[8 | 9]`
- `10`을 넣으면 `[8 | 9 | 10]` overflow
- `9`가 부모 `[2 | 7]`로 올라가면서 부모도 overflow
- 부모를 다시 분할하고 `7`이 루트로 승진

![삽입 Step 6]({{ '/assets/b-tree-summary/09-step-6.svg' | relative_url }})

### Step 7. 50, 70, 60, 40 삽입 후 최종 트리

- `50`은 `[90]`에 들어가 `[50 | 90]`
- `70`을 넣으면 `[50 | 70 | 90]` overflow, `70` 승진
- 오른쪽 인터널 노드가 `[30 | 70]`이 된다
- `60`은 가운데 리프에 들어가 `[50 | 60]`
- `40`을 넣으면 `[40 | 50 | 60]` overflow, `50` 승진
- 오른쪽 인터널이 overflow되고, 마지막으로 루트도 분할된다

최종 결과:

![삽입 Step 7 최종 트리]({{ '/assets/b-tree-summary/10-step-7-final.svg' | relative_url }})

## 7. 삽입 변화 한눈에 보기

| 삽입 값 | 결과 요약 |
| --- | --- |
| 1 | 루트 `[1]` |
| 15 | 루트 `[1 | 15]` |
| 2 | overflow, `2` 승진 -> 루트 `[2]` |
| 5 | 오른쪽 리프 `[5 | 15]` |
| 30 | overflow, `15` 승진 -> 루트 `[2 | 15]` |
| 90 | 오른쪽 리프 `[30 | 90]` |
| 20 | overflow, `30` 승진 -> 루트까지 overflow -> 새 루트 `[15]` |
| 7 | 리프 `[5 | 7]` |
| 9 | overflow, `7` 승진 -> 왼쪽 인터널 `[2 | 7]` |
| 8 | 리프 `[8 | 9]` |
| 10 | overflow, `9` 승진 -> 인터널 overflow -> `7`이 루트로 승진 |
| 50 | 리프 `[50 | 90]` |
| 70 | overflow, `70` 승진 -> 오른쪽 인터널 `[30 | 70]` |
| 60 | 리프 `[50 | 60]` |
| 40 | overflow, `50` 승진 -> 인터널 overflow -> 루트 분할 -> 최종 루트 `[15]` |

## 8. B+Tree 기본 구조

B+Tree는 B-Tree와 비슷하지만, **실제 데이터는 leaf node에만 저장**하고 internal node는 탐색용 key만 둔다.

- internal node: 어느 방향으로 내려갈지 결정하는 안내판 역할
- leaf node: 실제 key 또는 레코드 위치를 저장
- 모든 leaf는 같은 높이에 있고, 보통 서로 연결된다

예시:

![B+Tree 구조]({{ '/assets/b-tree-summary/11-bplustree-structure.svg' | relative_url }})

위 그림에서는:

- 루트와 internal node는 탐색 경로를 나누는 key만 가진다
- 실제 값은 맨 아래 leaf에만 있다
- leaf들은 오른쪽으로 연결되어 있어서 순차 탐색이 쉽다

## 9. B+Tree에서 leaf 연결이 중요한 이유

B+Tree는 값을 찾은 뒤 같은 구간의 다음 값들을 읽을 때 다시 루트로 올라갈 필요가 없다.  
처음 leaf만 찾으면, 이후에는 연결된 leaf를 따라 오른쪽으로 이동하면 된다.

![B+Tree leaf 연결]({{ '/assets/b-tree-summary/12-bplustree-leaf-chain.svg' | relative_url }})

이 구조 덕분에 B+Tree는 다음 작업에 특히 유리하다.

- 범위 검색: `20 이상 70 이하`
- 정렬 순회: 작은 값부터 큰 값까지 출력
- 데이터베이스 인덱스 스캔

## 10. B-Tree와 B+Tree 차이

### B-Tree

- internal node와 leaf node 모두 key를 가질 수 있다
- 검색 도중 internal node에서 바로 값을 찾을 수도 있다
- 범위 검색은 가능하지만 leaf 연속 순회 구조는 B+Tree보다 덜 직접적이다

### B+Tree

- 실제 데이터는 leaf에만 저장한다
- internal node는 탐색 전용 key만 가진다
- leaf node들이 연결되어 있어 범위 검색과 순차 접근에 강하다

한 줄 비교:

- B-Tree: "중간 노드에도 값이 들어갈 수 있는 트리"
- B+Tree: "중간 노드는 길 안내, 실제 데이터는 leaf에 모아둔 트리"

## 11. B+Tree 삽입 과정

여기서는 **3차 B+Tree** 느낌으로 간단한 삽입 흐름만 본다.

- internal node의 역할: 경로 안내
- 실제 key는 leaf에 저장
- leaf가 overflow되면 **분할한 뒤, 오른쪽 leaf의 첫 key를 부모에 복사해서 올린다**

이 지점이 B-Tree와 다르다.  
B-Tree는 가운데 key가 위로 **승진**하면서 원래 자리에서 빠질 수 있지만,  
B+Tree는 leaf에 실제 데이터가 남아 있어야 하므로 separator key를 부모에 **복사**한다.

### Step 1. 시작 상태

![B+Tree 삽입 시작]({{ '/assets/b-tree-summary/13-bplustree-insert-start.svg' | relative_url }})

루트가 leaf인 상태에서 시작한다.

### Step 2. 30 삽입 -> 루트 leaf 분할

`[10 | 20]`에 `30`을 넣으면 leaf overflow가 발생한다.

- leaf를 둘로 나눈다
- 오른쪽 leaf의 첫 key `20`을 부모에 복사한다
- 루트가 분할되었으므로 새 루트가 생긴다

![B+Tree 루트 분할]({{ '/assets/b-tree-summary/14-bplustree-insert-root-split.svg' | relative_url }})

중요한 점:

- 부모에는 `20`이 들어가지만
- leaf에도 `20`이 그대로 남아 있다

### Step 3. 25 삽입 -> leaf split + 부모 key 추가

`25`는 오른쪽 leaf `[20 | 30]`에 들어가서 overflow를 만든다.

- `[20 | 25 | 30]`을 `[20]`, `[25 | 30]`으로 분할
- 새 오른쪽 leaf의 첫 key `25`를 부모에 복사

![B+Tree 두 번째 leaf 분할]({{ '/assets/b-tree-summary/15-bplustree-insert-second-split.svg' | relative_url }})

이후에도 삽입 규칙은 같다.

1. leaf에 삽입
2. overflow면 leaf split
3. 오른쪽 leaf의 첫 key를 부모에 복사
4. 부모도 overflow면 internal node split
5. 루트가 overflow면 새 루트 생성

## 12. B-Tree 삭제 기본

B-Tree 삭제는 삽입보다 조금 더 복잡하다.  
삭제 후 어떤 노드의 key 수가 최소 개수보다 작아지면 **underflow**가 발생하고, 이때:

1. 형제에게서 하나 빌릴 수 있으면 **재분배**
2. 못 빌리면 부모 key와 함께 **병합**

참고로 internal node에서 key를 삭제할 때는 보통:

- 왼쪽 서브트리의 최대값(전임자, predecessor)
- 또는 오른쪽 서브트리의 최소값(후임자, successor)

로 대체한 뒤, 실제 삭제는 leaf에서 처리한다.

### Case 1. 단순 삭제

삭제 전:

![B-Tree 단순 삭제 전]({{ '/assets/b-tree-summary/16-btree-delete-simple-before.svg' | relative_url }})

여기서 `10`을 삭제하면 왼쪽 leaf는 `[5]`가 된다.  
3차 B-Tree에서 leaf의 최소 key 수는 1이므로 underflow가 아니다.

삭제 후:

![B-Tree 단순 삭제 후]({{ '/assets/b-tree-summary/17-btree-delete-simple-after.svg' | relative_url }})

즉, 삭제 후에도 최소 조건을 만족하면 아무 재조정도 하지 않는다.

## 13. B-Tree 재분배(빌려오기)

이번에는 삭제 때문에 어떤 leaf가 최소 조건을 깨는 경우다.

삭제 직전 상태:

![B-Tree 재분배 전]({{ '/assets/b-tree-summary/18-btree-redistribute-before.svg' | relative_url }})

여기서 왼쪽 leaf의 `5`를 삭제하면 왼쪽 노드는 비게 된다.  
하지만 오른쪽 형제 `[20 | 30]`은 key가 2개라서 하나를 빌려줄 수 있다.

재분배 후:

![B-Tree 재분배 후]({{ '/assets/b-tree-summary/19-btree-redistribute-after.svg' | relative_url }})

흐름은 다음과 같다.

- 부모 key `15`를 왼쪽 자식으로 내려 보낸다
- 오른쪽 형제의 가장 작은 key `20`이 부모로 올라온다

결과적으로:

- 부모: `[20]`
- 왼쪽 자식: `[15]`
- 오른쪽 자식: `[30]`

이렇게 형제에게서 하나 빌려오는 과정을 **재분배(redistribution)** 또는 **borrow**라고 한다.

## 14. B-Tree 병합(merge)

형제가 최소 key만 가지고 있다면, 더 이상 빌릴 수 없다.  
이때는 부모의 separator key를 내려 보내고 형제와 합쳐서 하나의 노드로 만든다.

삭제 직전 상태:

![B-Tree 병합 전]({{ '/assets/b-tree-summary/20-btree-merge-before.svg' | relative_url }})

여기서 왼쪽 leaf의 `10`을 삭제하면 왼쪽 leaf가 비게 된다.  
오른쪽 형제 `[30]`도 최소 key 수만 가지고 있으므로 빌려줄 수 없다.

그래서:

- 부모 key `20`을 아래로 내리고
- 오른쪽 형제 `[30]`과 합쳐서
- 하나의 노드 `[20 | 30]`으로 만든다

병합 후:

![B-Tree 병합 후]({{ '/assets/b-tree-summary/21-btree-merge-after.svg' | relative_url }})

이 예시에서는 루트가 비게 되어 트리 높이가 1 줄어든다.  
즉, **병합은 트리 높이를 감소시킬 수도 있다.**


## 16. 한 줄로 정리

BST는 자식이 최대 2개인 기본 탐색 트리이고, B-Tree는 한 노드에 여러 key를 넣어 높이를 줄인 균형 트리이며, B+Tree는 실제 데이터를 leaf에만 모아 범위 검색까지 빠르게 만든 구조다.
