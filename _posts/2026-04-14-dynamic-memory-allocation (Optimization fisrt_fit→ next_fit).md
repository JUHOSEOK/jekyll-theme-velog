---
title: Dynamic Memory Allocation  (Optimization fisrt_fit→ next_fit)
description: fisrt_fit의 방식을 next_fit방식으로 전환을 통해 최적화를 진행한다.
date: 2026-04-14 16:00:00 +0900
tags:
  - C
  - Memory
  - Allocator
  - malloc
  - free
---

# Dynamic Memory Allocation (Optimization fisrt_fit→next_fit)

- 현재 mdriver 결과

```c
Results for mm malloc:
trace  valid  util     ops      secs  Kops
 0       yes   99%    5694  0.005180  1099
 1       yes   99%    5848  0.003205  1825
 2       yes   99%    6648  0.005431  1224
 3       yes  100%    5380  0.003890  1383
 4       yes   66%   14400  0.000059245734
 5       yes   92%    4800  0.003247  1478
 6       yes   92%    4800  0.003012  1594
 7       yes   55%   12000  0.086887   138
 8       yes   51%   24000  0.152517   157
 9       yes   27%   14401  0.033016   436
10       yes   34%   14401  0.001337 10774
Total          74%  112372  0.297778   377
```

- Kops (throughtput) 처리량
- util (utilzation) 메모리이용도
- trace 7, 8에서 throughput이 심각하게 떨어짐 → find_fit 병목
- trace 4, 7, 8, 9에서 util 낮음 → fragmentation (단편화) 문제

처음부터 끝까지 탐색하여 free공간을 찾는 묵시적 리스트 + 처음의 요청 했던 공간이 나오면 바로 할당하는 first fit  방식 

앞부분에 free block이 있더라고 요청 크기에 맞지 않는 작은 조각들이 많아 사용하지 못하는 문하고 앞부분을 무시하고 뒤까지 찾아 처리량과 메모리 이용도가 떨어지는 현상이 나타남

#### find_fit 병목 문제의 원인

- implicit free list라서 전체 힙을 선형 탐색함
- first fit이라 매번 앞에서부터 다시 검사함
- 앞부분에 요청 크기를 만족하지 못하는 작은 free block이 많아지면 검사 비용이 커짐

#### 단편화 문제의 원인

- split 이후 남은 작은 free block들이 축적됨
- alloc/free 패턴 때문에 free 공간이 연속되지 않고 흩어짐
- coalescing은 인접 free block만 합칠 수 있어서 조각난 공간을 완전히 해결하지 못함

---

```c
0: amptjp-bal.rep
1: cccp-bal.rep
2: cp-decl-bal.rep
3: expr-bal.rep
4: coalescing-bal.rep
5: random-bal.rep
6: random2-bal.rep
7: binary-bal.rep
8: binary2-bal.rep
9: realloc-bal.rep
10: realloc2-bal.rep
```

첫번째 해결방법 

- trace 7, 8을 해결하기 위한 next_fit 방식 채택
- 현재 trace 7 패턴 분석
    
    ### 1단계
    
    ```
    a 0 64
    a 1 448
    a 2 64
    a 3 448
    ...
    ------------------------------------------------------------
    - 작은 블록 (64)
    - 큰 블록 (448)
    - 반복
    ```
    
    - **작은/큰 블록을 번갈아가며 엄청 많이 할당**
    
    ### 2단계
    
    ```
    f 1
    f 3
    f 5
    ...
    ```
    
    - **큰 블록들만 free**
    
    ### 결과
    
    힙 상태
    
    ```
    [64][free 448][64][free 448][64][free 448]...
    ```
    
    - free block 엄청 많음
    - 힙 길이 엄청 길어짐
    
    ### 3단계
    
    뒤쪽 보면:
    
    ```
    a 4000 512
    a 4001 512
    ...
    ```
    
    - 큰 블록 다시 할당 시작
    
    #### find_fit 상황
    
    ```
    find_fit(512) 할당할시 
    -->
     
    [64] → 안됨
    [free 448] → 안됨
    [64] → 안됨
    [free 448] → 안됨
    ...
    (수천 개 반복)
    ```
    
    - **끝까지 다 보고 나서야 큰 블록 찾음**

---

#### mm_realloc()

- mm_realloc()
    - mm_realloc
        
        ```c
        void *mm_realloc(void *ptr, size_t size)
        {
            void *newptr;
            size_t copySize;
        
            if (ptr == NULL) {
                return mm_malloc(size);
            }
        
            if (size == 0) {
                mm_free(ptr);
                return NULL;
            }
        
            newptr = mm_malloc(size);
            if (newptr == NULL) {
                return NULL;
            }
        
            copySize = GET_SIZE(HDRP(ptr)) - DSIZE;
            if (size < copySize) {
                copySize = size;
            }
        
            memcpy(newptr, ptr, copySize);
            mm_free(ptr);
            return newptr;
        }
        
        ```
        
    
    `realloc(bp, size)`의 뜻 == 최종적으로 확보하고 싶은 새 메모리 크기
    
    > 현재 블록이 이미 새 요청을 만족하면, 굳이 새 블록을 만들 필요는 없다
    > 
    
    ```
    "기존 블록 bp의 데이터를 유지하면서,
    크기를 size로 바꿔라"
    ```
    
    - 더 크게 바꿀 수도 있고
    - 더 작게 바꿀 수도 있고
    - 없애버릴 수도 있고
    - 새로 만들 수도 있음
    
    1단계: `bp == NULL`
    
    ```c
    if (bp == NULL) {
        return mm_malloc(size);
    }
    -------------------------------------------
    기존 블럭이 없으니 그냥 새로 만들어버림
    realloc(NULL, size) == malloc(size)
    ```
    
    2단계: `size == 0`
    
    ```c
    if (size == 0) {
        mm_free(bp);
        return NULL;
    }
    ```
    
    - 크기가 0 이라는 의미는 필요없다는의미
    - 기존 bp 블럭 free로 만듬
    
    ```c
    기존:
    [ old block ]
        ^
        bp
    
    realloc(bp, 0)
    -> free(bp)
    
    결과:
    [ free block ]
    ```
    
    3단계: 새 블록 만들기
    
    ```c
    newptr = mm_malloc(size);
    if (newptr == NULL) {
        return NULL;
    }
    ```
    
    - 기존 블록이 있고, 새 크기도 0이 아니니까,
    - 새 크기에 맞는 새 블록을 하나 만듬
    
    ```
    [ old H | old payload | old F ]
              ^
              bp
    ```
    
    새 블록 생성 후 → 
    
    ```
    [ old H | old payload | old F ]      [ new H | new payload | new F ]
              ^                                    ^
              bp                                 newptr
              
    -----------------------------------------------------------------------
    이미 mm_malloc으로 인해 new block의 header/footer는 준비 완료
    이제 bp의 old payload를 new payload로 옮겨야함
    ```
    
    **4단계: 복사할 크기 계산**
    
    ```c
    copySize = GET_SIZE(HDRP(bp)) - DSIZE;
    ```
    
    - 전체크기 - 8바이트(header, footer크기) == payload크기
    
    **5단계: 너무 많이 복사하지 않게 조정**
    
    ```c
    if (size < copySize) {
        copySize = size;
    }
    ```
    
    - 요청한 사이즈가 기존 old payload에 데이터의 크기보다 작으면
    - 요청한 사이즈대로 됨 → 데이터 손실됨
    
    6단계: 실제 복사
    
    ```c
    memcpy(newptr, bp, copySize)
    = old payload -> new payload
    ```
    
    7단계: 기존 블록 free
    
    ```c
    mm_free(bp);
    ```
    
    복사 전:
    
    ```
    [ old block ]      [ new block ]
        ^                  ^
        bp               newptr
    ```
    
    복사 후 free:
    
    ```
    [ free block ]     [ new block with copied data ]
                           ^
                         newptr
    ```
    
    **8단계: 새 포인터 반환**
    
    ```c
    return newptr;
    ```
    
    #### 시작
    
    ```
    [ old H | old payload DATA | old F ]
              ^
              bp
    ```
    
    #### 새 블록 생성
    
    ```
    [ old H | old payload DATA | old F ]     [ new H | new payload | new F ]
              ^                                       ^
              bp                                    newptr
    ```
    
    #### payload만 복사
    
    ```
    [ old H | old payload DATA | old F ]     [ new H | new payload DATA | new F ]
              ^                                       ^
              bp                                    newptr
    ```
    
    #### old block free
    
    ```
    [ free block ]                           [ new H | new payload DATA | new F ]
                                                   ^
                                                 newptr
    ```
    
    #### 반환
    
    ```
    return newptr;
    ```
    

```c
0: amptjp-bal.rep
1: cccp-bal.rep
2: cp-decl-bal.rep
3: expr-bal.rep
4: coalescing-bal.rep
5: random-bal.rep
6: random2-bal.rep
7: binary-bal.rep
8: binary2-bal.rep
9: realloc-bal.rep
10: realloc2-bal.rep
```

#### **변경전후 : implicit list (first_fit) -> implicit list (next_fit)**

- **implicit list (first_fit)**

Results for mm malloc:
trace  valid  util     ops      secs  Kops
0       yes   99%    5694  0.005180  1099
1       yes   99%    5848  0.003205  1825
2       yes   99%    6648  0.005431  1224
3       yes  100%    5380  0.003890  1383
4       yes   66%   14400  0.000059245734
5       yes   92%    4800  0.003247  1478
6       yes   92%    4800  0.003012  1594
7       yes   55%   12000  0.086887   138
8       yes   51%   24000  0.152517   157
9       yes   27%   14401  0.033016   436
10       yes   34%   14401  0.001337 10774
Total          74%  112372  0.297778   377

Perf index = 44 (util) + 26 (thru) = 70/100

- **implicit list (next_fit)**

Results for mm malloc:
trace  valid  util     ops      secs  Kops
0       yes   91%    5694  0.001868  3048
1       yes   92%    5848  0.000735  7959
2       yes   96%    6648  0.002205  3015
3       yes   96%    5380  0.002318  2321
4       yes   66%   14400  0.000072200278
5       yes   91%    4800  0.002264  2121
6       yes   90%    4800  0.001992  2410
7       yes   55%   12000  0.008668  1384
8       yes   51%   24000  0.003968  6048
9       yes   27%   14401  0.033191   434
10       yes   53%   14401  0.000064225368
Total          73%  112372  0.057344  1960

Perf index = 44 (util) + 40 (thru) = 84/100

- 바꾼 코드들 리뷰
    
    **1. 전역 변수 / 함수 원형 추가**
    
    ```c
    static char *heap_listp;
    static char *rover;  // 추가: next fit의 "탐색 시작점"을 기억하는 커서
    
    static void *extend_heap(size_t words);
    static void *coalesce(void *bp);
    static void *find_fit(size_t asize);
    static void place(void *bp, size_t asize);
    static size_t adjust_block_size(size_t size);            // 추가: size 계산 규칙 일원화
    static int can_expand_into_next(void *bp, size_t asize); // 추가: realloc 제자리 확장 가능 여부 검사
    static void expand_into_next(void *bp, size_t asize);    // 추가: realloc 제자리 확장 수행
    ```
    
    **2. mm_init**
    
    ```c
    int mm_init(void)
    {
        if ((heap_listp = mem_sbrk(4 * WSIZE)) == (void *)-1) {
            return -1;
        }
    
        PUT(heap_listp, 0);
        PUT(heap_listp + (1 * WSIZE), PACK(DSIZE, 1));
        PUT(heap_listp + (2 * WSIZE), PACK(DSIZE, 1));
        PUT(heap_listp + (3 * WSIZE), PACK(0,1));
        heap_listp += (2 * WSIZE);
    
        rover = heap_listp;  // 추가: 처음에는 힙 시작점에서 next fit 탐색을 시작하게 함
    
        if (extend_heap(CHUNKSIZE / WSIZE) == NULL) {
            return -1;
        }
    
        return 0;
    }
    ```
    
    **3. find_fit**
    
    ```c
    static void *find_fit(size_t asize)
    {
        void *bp;
    
        // 변경: heap 처음부터 매번 찾지 않고 rover부터 끝까지 먼저 탐색
        for (bp = rover; GET_SIZE(HDRP(bp)) > 0; bp = NEXT_BLKP(bp)) {
            if (!GET_ALLOC(HDRP(bp)) && (asize <= GET_SIZE(HDRP(bp)))) {
                return bp;
            }
        }
    
        // 변경: 끝까지 못 찾으면 앞부분(heap 시작 ~ rover 직전)만 다시 탐색
        // 이유: 힙 전체를 최대 한 바퀴만 보게 해서 반복 스캔 비용을 줄이려는 것
        for (bp = heap_listp; bp != rover; bp = NEXT_BLKP(bp)) {
            if (!GET_ALLOC(HDRP(bp)) && (asize <= GET_SIZE(HDRP(bp)))) {
                return bp;
            }
        }
        return NULL;
    }
    ```
    
    **4. mm_malloc**
    
    ```c
    void *mm_malloc(size_t size)
    {
        size_t asize;
        char *bp;
    
        if (size == 0) {
            return NULL;
        }
    
        // 변경: block size 계산을 helper로 분리
        // 이유: malloc/realloc이 같은 size 계산 규칙을 공유하게 하려는 것
        asize = adjust_block_size(size);
    
        if ((bp = find_fit(asize)) != NULL) {
            place(bp, asize);
            return bp;
        }
    
        if ((bp = extend_heap(MAX(asize, CHUNKSIZE) / WSIZE)) == NULL) {
            return NULL;
        }
    
        place(bp, asize);
        return bp;
    }
    ```
    
    **5. place**
    
    ```c
    static void place(void *bp, size_t asize)
    {
        size_t csize = GET_SIZE(HDRP(bp));
    
        if ((csize - asize) >= (2 * DSIZE)) {
            PUT(HDRP(bp), PACK(asize, 1));
            PUT(FTRP(bp), PACK(asize, 1));
    
            bp = NEXT_BLKP(bp);
            PUT(HDRP(bp), PACK(csize - asize, 0));
            PUT(FTRP(bp), PACK(csize - asize, 0));
    
            rover = bp;
            // 추가: split이 일어나면 남은 free block 쪽으로 rover를 이동
            // 이유: 다음 탐색이 방금 남겨둔 free 공간부터 시작되게 해서 next fit 효과를 살림
        } else {
            PUT(HDRP(bp), PACK(csize, 1));
            PUT(FTRP(bp), PACK(csize, 1));
    
            rover = NEXT_BLKP(bp);
            // 추가: split이 없으면 다음 블록으로 rover 이동
            // 이유: 같은 블록/앞부분을 반복 탐색하지 않게 하려는 것
        }
    }
    ```
    
    **6. coalesce**
    
    ```c
    static void *coalesce (void* bp) {
    
        size_t prev_alloc = GET_ALLOC(FTRP(PREV_BLKP(bp)));
        size_t next_alloc = GET_ALLOC(HDRP(NEXT_BLKP(bp)));
        size_t size = GET_SIZE(HDRP(bp));
    
        if (prev_alloc && next_alloc) {
            return bp;
        } else if (prev_alloc && !next_alloc) {
            size += GET_SIZE(HDRP(NEXT_BLKP(bp)));
            PUT(HDRP(bp), PACK(size,0));
            PUT(FTRP(bp), PACK(size,0));
    
        } else if (!prev_alloc && next_alloc) {
            size += GET_SIZE(HDRP(PREV_BLKP(bp)));
            PUT(FTRP(bp), PACK(size, 0));
            PUT(HDRP(PREV_BLKP(bp)), PACK(size, 0));
            bp = PREV_BLKP(bp);
    
        } else {
            size += GET_SIZE(HDRP(PREV_BLKP(bp)))
                  + GET_SIZE(HDRP(NEXT_BLKP(bp)));
            PUT(HDRP(PREV_BLKP(bp)), PACK(size, 0));
            PUT(FTRP(NEXT_BLKP(bp)), PACK(size, 0));
            bp = PREV_BLKP(bp);
        }
    
        if ((rover > (char *)bp) && (rover < NEXT_BLKP(bp))) {
            rover = bp;
            // 추가: rover가 병합된 큰 free block 내부를 가리키고 있으면
            // 병합 결과 블록의 시작점으로 되돌림
            // 이유: rover가 "유효한 블록 시작점"이 아니면 find_fit이 잘못된 header를 읽어서
            // overlap / heap outside 같은 오류가 날 수 있음
        }
    
        return bp;
    }
    ```
    
    **7. mm_realloc**
    
    ```c
    void *mm_realloc(void *bp, size_t size)
    {
        void *newptr;
        size_t copySize;
    
        if (bp == NULL) {
            return mm_malloc(size);
            // 유지/정리: realloc(NULL, size)는 malloc과 동일하게 처리
        }
    
        if (size == 0) {
            mm_free(bp);
            return NULL;
            // 유지/정리: realloc(ptr, 0)은 free와 동일하게 처리
        }
    
        size_t oldsize = GET_SIZE(HDRP(bp));
        size_t asize = adjust_block_size(size);
        // 변경: realloc도 malloc과 같은 block size 계산 사용
    	
        if (asize <= oldsize) {
            return bp;
            // 추가: 현재 블록이 이미 충분히 크면 새로 malloc/memcpy/free 함
    
            size_t remainder = oldsize - asize;
    				
    				// 추가 : 뒤에 공간이 최소 크기 16 바이트 이상이면 뒤에꺼 free해줌
            if (remainder >= 2 * DSIZE) {
                
                PUT(HDRP(bp), PACK(asize, 1));
                PUT(FTRP(bp), PACK(asize, 1));
    
                void *split_bp = NEXT_BLKP(bp);
                PUT(HDRP(split_bp),  PACK(remainder, 0));
                PUT(FTRP(split_bp),  PACK(remainder, 0));
    
                if ((rover > (char *)bp) && (rover < NEXT_BLKP(split_bp))) {
                    rover = split_bp;
                }
    
                coalesce(split_bp);
            }
            
    			return bp;
    			
        }
    
        if (can_expand_into_next(bp, asize)) {
            expand_into_next(bp, asize);
            return bp;
            // 추가: 다음 블록이 free이고 합치면 충분하면 제자리 확장
            // 이유: realloc trace에서 malloc+memcpy+free를 피하려고
        }
    
        newptr = mm_malloc(size);
        if (newptr == NULL) {
            return NULL;
        }
    
        copySize = GET_SIZE(HDRP(bp)) - DSIZE;
        if (size < copySize) {
            copySize = size;
        }
    
        memcpy(newptr, bp, copySize);
        mm_free(bp);
        return newptr;
    }
    ```
    
    **8. adjust_block_size**
    
    ```c
    static size_t adjust_block_size(size_t size) {
        if (size <= DSIZE) {
            return 2 * DSIZE;
            // 추가: 최소 블록 크기 보장
            // 이유: 헤더/푸터 + 최소 payload를 담을 수 있어야 함
        } else {
            return DSIZE * ((size + DSIZE + (DSIZE - 1)) / DSIZE);
            // 추가: 헤더/푸터 포함 후 8바이트 정렬된 실제 block size 계산
            // 이유: malloc/free/realloc이 동일한 규칙으로 block 크기를 맞추게 하려는 것
        }
    }
    ```
    
    **9. can_expand_into_next**
    
    ```c
    static int can_expand_into_next(void *bp, size_t asize)
    {
        void *next_bp = NEXT_BLKP(bp);
    
        if (GET_SIZE(HDRP(next_bp)) == 0) {
            return 0;
            // 추가: epilogue면 확장 불가
        }
    
        if (GET_ALLOC(HDRP(next_bp))) {
            return 0;
            // 추가: 다음 블록이 할당 중이면 흡수 불가
        }
    
        if (GET_SIZE(HDRP(bp)) + GET_SIZE(HDRP(next_bp)) >= asize) {
            return 1;
            // 추가: 현재 블록 + 다음 free 블록 크기가 요청 크기를 만족하면 확장 가능
        }
    
        return 0;
    }
    ```
    
    **10. expand_into_next**
    
    ```c
    static void expand_into_next(void *bp, size_t asize)
    {
        void *next_bp = NEXT_BLKP(bp);
        size_t oldsize = GET_SIZE(HDRP(bp));
        size_t nextsize = GET_SIZE(HDRP(next_bp));
        size_t combined = oldsize + nextsize;
    
        if (combined - asize >= 2 * DSIZE) {
            PUT(HDRP(bp), PACK(asize, 1));
            PUT(FTRP(bp), PACK(asize, 1));
            // 변경: 요청 크기만큼 현재 블록을 확장해서 allocated로 유지
    
            void *split_bp = NEXT_BLKP(bp);
            PUT(HDRP(split_bp), PACK(combined - asize, 0));
            PUT(FTRP(split_bp), PACK(combined - asize, 0));
            // 추가: 남는 공간이 충분하면 뒤를 다시 free block으로 남겨둠
            // 이유: utilization을 덜 해치기 위해
        }
        else {
            PUT(HDRP(bp), PACK(combined, 1));
            PUT(FTRP(bp), PACK(combined, 1));
            // 추가: 애매하게 남는 작은 조각은 split하지 않고 전부 현재 블록에 포함
            // 이유: 쓸모없는 작은 free block 생성을 막기 위해
            
        // 추가 필요: rover 보정
        void *merged_end = NEXT_BLKP(bp); // expand 후 bp의 다음 블록
        if ((rover > (char *)bp) && (rover < merged_end)) {
            rover = bp; // 또는 split 결과 free block 위치로
    
    	    }
    	}
    }
    ```