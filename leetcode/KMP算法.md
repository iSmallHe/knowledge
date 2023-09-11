# KMP算法
    该算法用于再给定的字符串中查找存在子串与目标匹配的字符串

### 普通思路
```java
public int strStr(String haystack, String needle) {
    char c = needle.charAt(0);
    int length = needle.length();
    int haystackLen = haystack.length();
    if (length == haystackLen) {
        if (haystack.equals(needle)) {
            return 0;
        }
    } else if (length < haystackLen) {
        for (int i = 0; i <= haystackLen - length; i++) {
            char c1 = haystack.charAt(i);
            if (c1 == c) {
                int j = 1;
                while (j < length ) {
                    if (haystack.charAt(j + i) != needle.charAt(j)) {
                        break;
                    }
                    j++;
                }
                if (j == length) {
                    return i;
                }
            }
        }
    }
    return -1;
}
```
    在上述方法中，我们以首字符来进行判断，如果相同，则进行后续的字符判断，（假设haystack = "aaaaaaaaaaav", needle = "aaac"）但是显而易见的是我们判断过的字符串会再进行重复判断，这并未利用到之前的判断信息，从而造成性能损耗，而且该方法的最差时间复杂度O(m*n)。那么怎么利用判断过的讯息，跳过那些重复判断？这就是接下来的KPM算法的巧妙之处。
### PMT序列
计算字符串中是否有存在前缀子串与后缀子串相同的最大长度(其中的子串不包含整个字符串)  <br/>

    匹配串P = abcabc  
    从下标为0处开始判断：  
    显而易见，0只有一个字符串不存在子串  
    长度=0  
    1. ab  
    前缀子串：a  
    后缀子串：b  
    长度=0  

    2. abc 
    前缀子串：a,ab  
    后缀子串：c,bc  
    长度=0  

    3. abca 
    前缀子串：a,ab,abc  
    后缀子串：a,ca,bca  
    长度=1 

    4. abcab  
    前缀子串：a,ab,abc,abca  
    后缀子串：b,ab,cab,bcab  
    长度=2  

    5. abcabc  
    前缀子串：a,ab,abc,abca,abcab  
    后缀子串：c,bc,abc,cabc,bcabc  
    长度=3  

    由此，我们可以得到一个关系：假设匹配的字符串中，只有部分前缀相同，那么我们可以从这部分已判断过的字符串中得到讯息，是否可以跳过这部分已匹配的字符串。从而避免一路进行循环匹配

    思考：我们如何快速得到这个前后缀的长度呢？
```java
// abddabcabddabd
public int[] needle(String needle) {
    int m = needle.length();
    int[] pi = new int[m];
    for (int i = 1, j = 0; i < m; i++) {
        while (j > 0 && needle.charAt(i) != needle.charAt(j)) {
            j = pi[j - 1];
        }
        if (needle.charAt(i) == needle.charAt(j)) {
            j++;
        }
        pi[i] = j;
    }
    return pi;
}
```

    在此，我们得到了该匹配串的前后缀的最大长度，这在后续的匹配过程中，将帮助我们过滤掉重复的判断，从而实现快速匹配

### match

```java
public int match(String haystack, String needle, int[] pi, int m, int n) {
    for (int i = 0, j = 0; i < n; i++) {
        while (j > 0 && haystack.charAt(i) != needle.charAt(j)) {
            j = pi[j - 1];
        }
        if (haystack.charAt(i) == needle.charAt(j)) {
            j++;
        }
        if (j == m) {
            return i - m + 1;
        }
    }
    return -1;
}
```