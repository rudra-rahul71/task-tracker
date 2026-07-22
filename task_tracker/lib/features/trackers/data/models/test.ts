function lengthOfLongestSubstring(s: string): number {
    let res = 0;
    let p1 = 0;
    let p2 = 0;
    const myMap = new Map<string, number>();

    while (p1 < s.length) {
        if (myMap.has(s[p1])) {
            p2 = Math.max(p2, myMap.get(s[p1])! + 1);
        }

        myMap.set(s[p1], p1);
        res = Math.max(res, p1 - p2 + 1);

        p1++;
    }


    return res;
};