// Tesla interview question set. Generated editorial content: intuition, walkthrough,
// complexity analysis, and brute-force + optimal solutions in Python/Java/C++.
// Each entry's `link` is the canonical LeetCode URL and is treated as the unique
// identity for a Problem record (see seed-tesla.ts). `companies` lists every company
// known to have asked this question; more companies can be appended later without
// creating a duplicate Problem row.

export type TeslaSeedProblem = {
  problemNumber: number
  title: string
  slug: string
  difficulty: 'EASY' | 'MEDIUM' | 'HARD'
  link: string
  topics: string[]
  companies: string[]
  frequency: number
  acceptanceRate: number
  problemStatement: string
  hints: string[]
  intuition: string
  walkthrough: string
  complexityAnalysis: string
  solutions: {
    python: string
    java: string
    cpp: string
  }
}

export const teslaProblems: TeslaSeedProblem[] = [
  {
    problemNumber: 3,
    title: 'Longest Substring Without Repeating Characters',
    slug: 'longest-substring-without-repeating-characters',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/longest-substring-without-repeating-characters',
    topics: ['Hash Table', 'String', 'Sliding Window'],
    companies: ['Tesla'],
    frequency: 82.6,
    acceptanceRate: 0.3694,
    problemStatement:
      'Given a string s, find the length of the longest substring without duplicate characters.\n\nExample 1:\nInput: s = "abcabcbb"\nOutput: 3\nExplanation: The answer is "abc", with the length of 3.\n\nExample 2:\nInput: s = "bbbbb"\nOutput: 1\n\nExample 3:\nInput: s = "pwwkew"\nOutput: 3\nExplanation: The answer is "wke", with the length of 3. Notice that the answer must be a substring, "pwke" is a subsequence and not a substring.\n\nConstraints:\n0 <= s.length <= 5 * 10^4\ns consists of English letters, digits, symbols and spaces.',
    hints: [
      'A brute force would check every substring for duplicates - that is O(n^3) since checking each substring for duplicates is O(n) on top of O(n^2) substrings.',
      'Can you avoid re-checking characters you already know are unique? A sliding window that grows and shrinks based on what you have seen is the key idea.',
      'A hash set (or a hash map storing the last seen index) lets you detect duplicates in O(1) and lets you jump the window start forward instead of moving it one step at a time.',
    ],
    intuition:
      'My first instinct as a student is just to try every substring and check if it has duplicates - that is the obvious brute force. But once I actually code it up I notice I am redoing a lot of work: if "abc" has no duplicates, and I then check "abcd", I am re-scanning a, b, c all over again just to add d. That repeated work is the signal that a sliding window will help. The window represents "the largest substring ending here with no duplicates so far." I keep a set of characters currently in the window. When I want to add a new character that is already in the set, I do not need to restart the window from scratch - I just shrink it from the left, removing characters one at a time, until the duplicate is gone. Every character still only gets added and removed from the set a constant number of times, so the whole scan is linear.',
    walkthrough:
      'Brute force: for every starting index i, walk forward with a local set, stop as soon as we hit a repeat, and record the length. Three nested levels of work (start index, inner walk, set lookups) make it O(n^3) in the worst case if we are not careful, or O(n^2) if we use a set efficiently per start.\n\nOptimal sliding window: keep two pointers left and right marking the current window [left, right]. Walk right across the string one character at a time. Before adding s[right] to the window, check if it is already in our set. If it is, keep removing s[left] from the set and incrementing left until the duplicate is gone. Then add s[right], and update the best answer with the current window size (right - left + 1). A small upgrade: instead of a plain set and a while-loop that removes one character at a time, store a map from character to its last seen index. When we see a duplicate, we can jump left directly to (last seen index + 1) instead of incrementing one at a time - this avoids any wasted iterations.',
    complexityAnalysis:
      'Brute force: Time O(n^2) using a set per starting index (each inner scan is O(n) and there are n starts); Space O(min(n, charset)) for the set used in each inner scan.\n\nOptimal sliding window: Time O(n) because left and right each move forward at most n times total across the whole run, never backward; Space O(min(n, charset)) for the hash map/set, since at most one entry per distinct character in the window.',
    solutions: {
      python: `class Solution:
    def lengthOfLongestSubstring(self, s: str) -> int:
        # Brute force: try every starting index, walk forward
        # until we hit a character we have already seen.
        n = len(s)
        best = 0
        for start in range(n):
            seen = set()
            length = 0
            for end in range(start, n):
                if s[end] in seen:
                    break
                seen.add(s[end])
                length += 1
            best = max(best, length)
        return best


class SolutionOptimal:
    def lengthOfLongestSubstring(self, s: str) -> int:
        # Optimal: sliding window with a map of char -> last index seen.
        last_seen = {}
        left = 0
        best = 0

        for right, ch in enumerate(s):
            if ch in last_seen and last_seen[ch] >= left:
                # duplicate inside our current window, shrink from the left
                left = last_seen[ch] + 1

            last_seen[ch] = right
            window_size = right - left + 1
            best = max(best, window_size)

        return best
`,
      java: `class Solution {
    // Brute force: try every starting index, walk forward
    // until we hit a character we have already seen.
    public int lengthOfLongestSubstring(String s) {
        int n = s.length();
        int best = 0;

        for (int start = 0; start < n; start++) {
            Set<Character> seen = new HashSet<>();
            int length = 0;
            for (int end = start; end < n; end++) {
                char c = s.charAt(end);
                if (seen.contains(c)) {
                    break;
                }
                seen.add(c);
                length++;
            }
            best = Math.max(best, length);
        }

        return best;
    }
}

class SolutionOptimal {
    // Optimal: sliding window with a map of char -> last index seen.
    public int lengthOfLongestSubstring(String s) {
        Map<Character, Integer> lastSeen = new HashMap<>();
        int left = 0;
        int best = 0;

        for (int right = 0; right < s.length(); right++) {
            char c = s.charAt(right);
            if (lastSeen.containsKey(c) && lastSeen.get(c) >= left) {
                left = lastSeen.get(c) + 1;
            }
            lastSeen.put(c, right);
            best = Math.max(best, right - left + 1);
        }

        return best;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: try every starting index, walk forward
    // until we hit a character we have already seen.
    int lengthOfLongestSubstring(string s) {
        int n = s.size();
        int best = 0;

        for (int start = 0; start < n; start++) {
            unordered_set<char> seen;
            int length = 0;
            for (int end = start; end < n; end++) {
                if (seen.count(s[end])) {
                    break;
                }
                seen.insert(s[end]);
                length++;
            }
            best = max(best, length);
        }

        return best;
    }
};

class SolutionOptimal {
public:
    // Optimal: sliding window with a map of char -> last index seen.
    int lengthOfLongestSubstring(string s) {
        unordered_map<char, int> lastSeen;
        int left = 0;
        int best = 0;

        for (int right = 0; right < (int)s.size(); right++) {
            char c = s[right];
            auto it = lastSeen.find(c);
            if (it != lastSeen.end() && it->second >= left) {
                left = it->second + 1;
            }
            lastSeen[c] = right;
            best = max(best, right - left + 1);
        }

        return best;
    }
};
`,
    },
  },
  {
    problemNumber: 1729,
    title: 'Find Followers Count',
    slug: 'find-followers-count',
    difficulty: 'EASY',
    link: 'https://leetcode.com/problems/find-followers-count',
    topics: ['Database'],
    companies: ['Tesla'],
    frequency: 95.3,
    acceptanceRate: 0.6956,
    problemStatement:
      'Table: Followers\n\n+-------------+------+\n| Column Name | Type |\n+-------------+------+\n| user_id     | int  |\n| follower_id | int  |\n+-------------+------+\n(user_id, follower_id) is the primary key (combination of columns with unique values) for this table.\nThis table contains the IDs of a user and a follower in a social media app where the follower follows the user.\n\nWrite a solution that will, for each user, return the number of followers.\n\nReturn the result table ordered by user_id in ascending order.\n\nExample 1:\nInput:\nFollowers table:\n+---------+-------------+\n| user_id | follower_id |\n+---------+-------------+\n| 0       | 1           |\n| 1       | 0           |\n| 2       | 0           |\n| 2       | 1           |\n+---------+-------------+\nOutput:\n+---------+----------------+\n| user_id | followers_count |\n+---------+----------------+\n| 0       | 1              |\n| 1       | 1              |\n| 2       | 2              |\n+---------+----------------+\nExplanation:\nThe followers of 0 are {1}.\nThe followers of 1 are {0}.\nThe followers of 2 are {0,1}.',
    hints: [
      'Each row in the Followers table is one follower-of relationship for a given user_id, so counting followers per user is just counting rows per user_id.',
      'GROUP BY user_id collapses all rows belonging to the same user into one group; COUNT then tells you how many followers that user has.',
      'Remember to ORDER BY user_id so the output is sorted as the problem requires.',
    ],
    intuition:
      'My first instinct is to think about how the data is laid out: every single row is one "this follower follows this user" fact. So the question "how many followers does each user have" is really "how many rows share the same user_id". One naive way I could imagine is, for each distinct user, run a separate correlated subquery that counts matching rows - but that means scanning the table once per user, which feels wasteful. The key realization is that SQL already has a clean primitive for "split rows into buckets by a column and compute something per bucket": GROUP BY together with COUNT. So I group by user_id and count the rows in each group, which the database can do in a single pass with hashing or sorting. The follower_id values themselves do not matter for the count, only how many there are, and since (user_id, follower_id) is the primary key there are no duplicate rows to worry about, so a plain COUNT is correct.',
    walkthrough:
      'This is a SQL problem, so there is a single query rather than separate brute-force and optimal code. The naive way to think about it would be a correlated subquery: for each user, count how many rows in Followers have that user_id - conceptually that is one COUNT per user, an O(n) scan repeated for each distinct user. The clean and efficient approach uses GROUP BY user_id, which buckets all rows by user, and COUNT(follower_id) to count the rows in each bucket. We alias the count as followers_count to match the required output column, and finish with ORDER BY user_id ASC so the result is sorted ascending by user as the problem demands.',
    complexityAnalysis:
      'Naive correlated-subquery approach: it conceptually rescans the table once for each distinct user, so it behaves like O(u * n) where u is the number of distinct users and n is the row count - the same total work duplicated per user.\n\nGROUP BY / COUNT approach: the database aggregates in roughly a single pass over the table using a hash or sort grouping, so the work is about O(n) plus the cost of the final ORDER BY sort (O(u log u) over the grouped rows). This is the standard, efficient query.',
    solutions: {
      python: `# This is a SQL problem; the same query is used for all three languages.
# Group the Followers table by user_id and count the rows in each group.
SELECT user_id, COUNT(follower_id) AS followers_count
FROM Followers
GROUP BY user_id
ORDER BY user_id ASC;
`,
      java: `-- This is a SQL problem; the same query is used for all three languages.
-- Group the Followers table by user_id and count the rows in each group.
SELECT user_id, COUNT(follower_id) AS followers_count
FROM Followers
GROUP BY user_id
ORDER BY user_id ASC;
`,
      cpp: `-- This is a SQL problem; the same query is used for all three languages.
-- Group the Followers table by user_id and count the rows in each group.
SELECT user_id, COUNT(follower_id) AS followers_count
FROM Followers
GROUP BY user_id
ORDER BY user_id ASC;
`,
    },
  },
  {
    problemNumber: 1758,
    title: 'Minimum Changes To Make Alternating Binary String',
    slug: 'minimum-changes-to-make-alternating-binary-string',
    difficulty: 'EASY',
    link: 'https://leetcode.com/problems/minimum-changes-to-make-alternating-binary-string',
    topics: ['String'],
    companies: ['Tesla'],
    frequency: 95.3,
    acceptanceRate: 0.6370,
    problemStatement:
      'You are given a string s consisting only of the characters \'0\' and \'1\'. In one operation, you can change any \'0\' to a \'1\' or vice versa.\n\nThe string is called alternating if no two adjacent characters are equal. For example, the string "010" is alternating, while the string "0100" is not.\n\nReturn the minimum number of operations needed to make s alternating.\n\nExample 1:\nInput: s = "0100"\nOutput: 1\nExplanation: If you change the last character to \'1\', s will be "0101", which is alternating.\n\nExample 2:\nInput: s = "10"\nOutput: 0\nExplanation: s is already alternating.\n\nExample 3:\nInput: s = "1111"\nOutput: 2\nExplanation: You need two operations to reach "0101" or "1010".\n\nConstraints:\n1 <= s.length <= 10^4\ns[i] is either \'0\' or \'1\'.',
    hints: [
      'An alternating binary string of a given length has only two possible forms: one starting with \'0\' (0101...) and one starting with \'1\' (1010...).',
      'Count how many characters in s differ from the pattern that starts with \'0\'. The number that differ from the pattern starting with \'1\' is just the rest.',
      'The answer is the minimum of the two mismatch counts.',
    ],
    intuition:
      'My first instinct is that an alternating string is extremely constrained: once I fix the first character, every other character is forced. So there really are only two valid targets of the same length - the one that goes 0,1,0,1,... and the one that goes 1,0,1,0,.... The naive idea would be to literally build both target strings and compare. But I notice I do not even need to build them: at each index i, the "starts with 0" pattern expects \'0\' when i is even and \'1\' when i is odd. So I can just walk the string once and count mismatches against that pattern. The clever realization is that I do not need to also count mismatches against the other pattern separately, because every position either matches pattern A or matches pattern B (they are exact opposites). So if mismatches_against_A characters need changing to reach pattern A, then the rest (length - mismatches_against_A) need changing to reach pattern B. The answer is the smaller of the two.',
    walkthrough:
      'Brute force: explicitly construct both candidate alternating strings of length n - one starting with \'0\', one starting with \'1\' - then compare s character by character against each and count differences, returning the smaller count. This builds extra strings and effectively scans twice.\n\nOptimal: do a single pass. Keep one counter mismatches_starting_zero. For each index i, the pattern that starts with \'0\' has \'0\' at even positions and \'1\' at odd positions; compute the expected character from i % 2, and if s[i] does not equal it, increment mismatches_starting_zero. After the loop, the count to make it start with \'1\' is simply n - mismatches_starting_zero, because the two target patterns are exact complements. Return min(mismatches_starting_zero, n - mismatches_starting_zero).',
    complexityAnalysis:
      'Brute force: Time O(n) to build the patterns plus O(n) to compare, so O(n) overall but with extra passes and string allocation; Space O(n) to hold the two constructed candidate strings.\n\nOptimal: Time O(n) for the single scan counting mismatches; Space O(1) because we only keep a couple of integer counters and never build a second string.',
    solutions: {
      python: `class Solution:
    def minOperations(self, s: str) -> int:
        # Brute force: build both target alternating strings and compare.
        n = len(s)
        pattern_zero = []
        pattern_one = []
        for i in range(n):
            if i % 2 == 0:
                pattern_zero.append('0')
                pattern_one.append('1')
            else:
                pattern_zero.append('1')
                pattern_one.append('0')

        changes_to_zero = sum(1 for i in range(n) if s[i] != pattern_zero[i])
        changes_to_one = sum(1 for i in range(n) if s[i] != pattern_one[i])
        return min(changes_to_zero, changes_to_one)


class SolutionOptimal:
    def minOperations(self, s: str) -> int:
        # Optimal: count mismatches against the pattern starting with '0'.
        # The pattern starting with '1' needs the rest of the changes.
        mismatches_starting_zero = 0
        for i, ch in enumerate(s):
            expected = '0' if i % 2 == 0 else '1'
            if ch != expected:
                mismatches_starting_zero += 1

        return min(mismatches_starting_zero, len(s) - mismatches_starting_zero)
`,
      java: `class Solution {
    // Brute force: build both target alternating strings and compare.
    public int minOperations(String s) {
        int n = s.length();
        StringBuilder patternZero = new StringBuilder();
        StringBuilder patternOne = new StringBuilder();
        for (int i = 0; i < n; i++) {
            if (i % 2 == 0) {
                patternZero.append('0');
                patternOne.append('1');
            } else {
                patternZero.append('1');
                patternOne.append('0');
            }
        }

        int changesToZero = 0;
        int changesToOne = 0;
        for (int i = 0; i < n; i++) {
            if (s.charAt(i) != patternZero.charAt(i)) {
                changesToZero++;
            }
            if (s.charAt(i) != patternOne.charAt(i)) {
                changesToOne++;
            }
        }
        return Math.min(changesToZero, changesToOne);
    }
}

class SolutionOptimal {
    // Optimal: count mismatches against the pattern starting with '0'.
    public int minOperations(String s) {
        int mismatchesStartingZero = 0;
        for (int i = 0; i < s.length(); i++) {
            char expected = (i % 2 == 0) ? '0' : '1';
            if (s.charAt(i) != expected) {
                mismatchesStartingZero++;
            }
        }

        return Math.min(mismatchesStartingZero, s.length() - mismatchesStartingZero);
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: build both target alternating strings and compare.
    int minOperations(string s) {
        int n = s.size();
        string patternZero(n, ' ');
        string patternOne(n, ' ');
        for (int i = 0; i < n; i++) {
            if (i % 2 == 0) {
                patternZero[i] = '0';
                patternOne[i] = '1';
            } else {
                patternZero[i] = '1';
                patternOne[i] = '0';
            }
        }

        int changesToZero = 0;
        int changesToOne = 0;
        for (int i = 0; i < n; i++) {
            if (s[i] != patternZero[i]) changesToZero++;
            if (s[i] != patternOne[i]) changesToOne++;
        }
        return min(changesToZero, changesToOne);
    }
};

class SolutionOptimal {
public:
    // Optimal: count mismatches against the pattern starting with '0'.
    int minOperations(string s) {
        int mismatchesStartingZero = 0;
        for (int i = 0; i < (int)s.size(); i++) {
            char expected = (i % 2 == 0) ? '0' : '1';
            if (s[i] != expected) {
                mismatchesStartingZero++;
            }
        }

        return min(mismatchesStartingZero, (int)s.size() - mismatchesStartingZero);
    }
};
`,
    },
  },
  {
    problemNumber: 227,
    title: 'Basic Calculator II',
    slug: 'basic-calculator-ii',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/basic-calculator-ii',
    topics: ['Math', 'String', 'Stack'],
    companies: ['Tesla'],
    frequency: 92.6,
    acceptanceRate: 0.4581,
    problemStatement:
      'Given a string s which represents an expression, evaluate this expression and return its value.\n\nThe integer division should truncate toward zero.\n\nYou may assume that the given expression is always valid. All intermediate results will be in the range of [-2^31, 2^31 - 1].\n\nNote: You are not allowed to use any built-in function which evaluates strings as mathematical expressions, such as eval().\n\nExample 1:\nInput: s = "3+2*2"\nOutput: 7\n\nExample 2:\nInput: s = " 3/2 "\nOutput: 1\n\nExample 3:\nInput: s = " 3+5 / 2 "\nOutput: 5\n\nConstraints:\n1 <= s.length <= 3 * 10^5\ns consists of integers and the operators \'+\', \'-\', \'*\', and \'/\' separated by some number of spaces.\ns represents a valid expression.\nAll the integers in the expression are non-negative integers in the range [0, 2^31 - 1].',
    hints: [
      'There are no parentheses here, so the only complication is operator precedence: \'*\' and \'/\' bind tighter than \'+\' and \'-\'.',
      'A stack lets you defer addition and subtraction: push numbers (negated for subtraction) and resolve multiplication/division immediately by popping the top of the stack.',
      'Track the previous operator. When you finish reading a number, act based on that operator; the final answer is the sum of everything left on the stack.',
    ],
    intuition:
      'My first thought is that without parentheses the only real challenge is that multiplication and division have to happen before addition and subtraction. A really naive approach I could take is to do two passes: first scan and resolve all the * and / operations into intermediate numbers, then sum/subtract what is left. That works but it is fiddly with the string manipulation. The cleaner mental model I keep coming back to is a stack of "terms that will eventually just be added together." If I see a plus, I push the number; if I see a minus, I push its negative. The trick is what to do with * and / - those need to combine with the number I most recently pushed, so I pop the top of the stack, apply the operation, and push the result back. By the time I reach the end, every term on the stack is something that should be added, so the answer is just the sum of the stack. The key realization is that tracking the operator that came before the current number is enough to decide whether to push, push-negative, or pop-and-combine.',
    walkthrough:
      'Brute force two-pass: convert the string into a list of numbers and operators, then first walk through resolving every \'*\' and \'/\' by combining adjacent numbers, leaving only \'+\' and \'-\'; then walk the reduced list adding and subtracting. It is correct but allocates intermediate token lists and scans multiple times.\n\nOptimal stack: maintain a stack of integers and a variable previous_operator initialized to \'+\'. Walk the string building up the current number from consecutive digits. When we hit an operator (or the end of the string), we look at previous_operator: if it was \'+\', push current_number; if \'-\', push -current_number; if \'*\', pop the top and push top * current_number; if \'/\', pop the top and push the truncated-toward-zero division. Then set previous_operator to the operator we just read and reset current_number to 0. After the loop, the result is the sum of everything on the stack.',
    complexityAnalysis:
      'Brute force: Time O(n) to tokenize plus O(n) for each reduction pass, so O(n) overall but with multiple passes; Space O(n) to store the token and number lists.\n\nOptimal: Time O(n) since we scan the string once and each number is pushed/popped a constant number of times; Space O(n) in the worst case for the stack (an expression of all additions pushes every number).',
    solutions: {
      python: `class Solution:
    def calculate(self, s: str) -> int:
        # Brute force: tokenize, resolve * and / in one pass,
        # then add and subtract what remains in a second pass.
        tokens = []
        i = 0
        n = len(s)
        while i < n:
            if s[i] == ' ':
                i += 1
            elif s[i].isdigit():
                num = 0
                while i < n and s[i].isdigit():
                    num = num * 10 + int(s[i])
                    i += 1
                tokens.append(num)
            else:
                tokens.append(s[i])
                i += 1

        # First pass: collapse * and /
        reduced = []
        j = 0
        while j < len(tokens):
            if tokens[j] == '*':
                prev = reduced.pop()
                reduced.append(prev * tokens[j + 1])
                j += 2
            elif tokens[j] == '/':
                prev = reduced.pop()
                reduced.append(int(prev / tokens[j + 1]))
                j += 2
            else:
                reduced.append(tokens[j])
                j += 1

        # Second pass: add and subtract
        result = reduced[0]
        k = 1
        while k < len(reduced):
            if reduced[k] == '+':
                result += reduced[k + 1]
            else:
                result -= reduced[k + 1]
            k += 2
        return result


class SolutionOptimal:
    def calculate(self, s: str) -> int:
        # Optimal: stack of terms to be summed; resolve * and / immediately.
        stack = []
        current_number = 0
        previous_operator = '+'

        for index, ch in enumerate(s):
            if ch.isdigit():
                current_number = current_number * 10 + int(ch)

            if (not ch.isdigit() and ch != ' ') or index == len(s) - 1:
                if previous_operator == '+':
                    stack.append(current_number)
                elif previous_operator == '-':
                    stack.append(-current_number)
                elif previous_operator == '*':
                    stack.append(stack.pop() * current_number)
                else:  # division truncating toward zero
                    stack.append(int(stack.pop() / current_number))
                previous_operator = ch
                current_number = 0

        return sum(stack)
`,
      java: `class Solution {
    // Brute force: tokenize, resolve * and / first, then + and -.
    public int calculate(String s) {
        List<Object> tokens = new ArrayList<>();
        int i = 0;
        int n = s.length();
        while (i < n) {
            char c = s.charAt(i);
            if (c == ' ') {
                i++;
            } else if (Character.isDigit(c)) {
                int num = 0;
                while (i < n && Character.isDigit(s.charAt(i))) {
                    num = num * 10 + (s.charAt(i) - '0');
                    i++;
                }
                tokens.add(num);
            } else {
                tokens.add(c);
                i++;
            }
        }

        List<Object> reduced = new ArrayList<>();
        int j = 0;
        while (j < tokens.size()) {
            Object t = tokens.get(j);
            if (t.equals('*')) {
                int prev = (int) reduced.remove(reduced.size() - 1);
                reduced.add(prev * (int) tokens.get(j + 1));
                j += 2;
            } else if (t.equals('/')) {
                int prev = (int) reduced.remove(reduced.size() - 1);
                reduced.add(prev / (int) tokens.get(j + 1));
                j += 2;
            } else {
                reduced.add(t);
                j++;
            }
        }

        int result = (int) reduced.get(0);
        int k = 1;
        while (k < reduced.size()) {
            char op = (char) reduced.get(k);
            int value = (int) reduced.get(k + 1);
            if (op == '+') {
                result += value;
            } else {
                result -= value;
            }
            k += 2;
        }
        return result;
    }
}

class SolutionOptimal {
    // Optimal: stack of terms to be summed; resolve * and / immediately.
    public int calculate(String s) {
        Deque<Integer> stack = new ArrayDeque<>();
        int currentNumber = 0;
        char previousOperator = '+';

        for (int index = 0; index < s.length(); index++) {
            char ch = s.charAt(index);
            if (Character.isDigit(ch)) {
                currentNumber = currentNumber * 10 + (ch - '0');
            }

            boolean isOperator = (ch != ' ' && !Character.isDigit(ch));
            if (isOperator || index == s.length() - 1) {
                if (previousOperator == '+') {
                    stack.push(currentNumber);
                } else if (previousOperator == '-') {
                    stack.push(-currentNumber);
                } else if (previousOperator == '*') {
                    stack.push(stack.pop() * currentNumber);
                } else {
                    stack.push(stack.pop() / currentNumber);
                }
                previousOperator = ch;
                currentNumber = 0;
            }
        }

        int result = 0;
        for (int value : stack) {
            result += value;
        }
        return result;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: tokenize, resolve * and / first, then + and -.
    int calculate(string s) {
        // Represent tokens as numbers; operators stored as separate marker.
        vector<long long> numbers;
        vector<char> ops;
        int i = 0;
        int n = s.size();
        // Parse into number/operator sequence: numbers[k] op[k] numbers[k+1] ...
        while (i < n) {
            if (s[i] == ' ') {
                i++;
            } else if (isdigit(s[i])) {
                long long num = 0;
                while (i < n && isdigit(s[i])) {
                    num = num * 10 + (s[i] - '0');
                    i++;
                }
                numbers.push_back(num);
            } else {
                ops.push_back(s[i]);
                i++;
            }
        }

        // First pass: collapse * and /
        vector<long long> reducedNums;
        vector<char> reducedOps;
        reducedNums.push_back(numbers[0]);
        for (int k = 0; k < (int)ops.size(); k++) {
            if (ops[k] == '*') {
                reducedNums.back() = reducedNums.back() * numbers[k + 1];
            } else if (ops[k] == '/') {
                reducedNums.back() = reducedNums.back() / numbers[k + 1];
            } else {
                reducedOps.push_back(ops[k]);
                reducedNums.push_back(numbers[k + 1]);
            }
        }

        // Second pass: add and subtract
        long long result = reducedNums[0];
        for (int k = 0; k < (int)reducedOps.size(); k++) {
            if (reducedOps[k] == '+') {
                result += reducedNums[k + 1];
            } else {
                result -= reducedNums[k + 1];
            }
        }
        return (int)result;
    }
};

class SolutionOptimal {
public:
    // Optimal: stack of terms to be summed; resolve * and / immediately.
    int calculate(string s) {
        vector<int> stack;
        int currentNumber = 0;
        char previousOperator = '+';

        for (int index = 0; index < (int)s.size(); index++) {
            char ch = s[index];
            if (isdigit(ch)) {
                currentNumber = currentNumber * 10 + (ch - '0');
            }

            bool isOperator = (ch != ' ' && !isdigit(ch));
            if (isOperator || index == (int)s.size() - 1) {
                if (previousOperator == '+') {
                    stack.push_back(currentNumber);
                } else if (previousOperator == '-') {
                    stack.push_back(-currentNumber);
                } else if (previousOperator == '*') {
                    int top = stack.back();
                    stack.pop_back();
                    stack.push_back(top * currentNumber);
                } else {
                    int top = stack.back();
                    stack.pop_back();
                    stack.push_back(top / currentNumber);
                }
                previousOperator = ch;
                currentNumber = 0;
            }
        }

        int result = 0;
        for (int value : stack) {
            result += value;
        }
        return result;
    }
};
`,
    },
  },
  {
    problemNumber: 56,
    title: 'Merge Intervals',
    slug: 'merge-intervals',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/merge-intervals',
    topics: ['Array', 'Sorting'],
    companies: ['Tesla'],
    frequency: 89.6,
    acceptanceRate: 0.4940,
    problemStatement:
      'Given an array of intervals where intervals[i] = [start_i, end_i], merge all overlapping intervals, and return an array of the non-overlapping intervals that cover all the intervals in the input.\n\nExample 1:\nInput: intervals = [[1,3],[2,6],[8,10],[15,18]]\nOutput: [[1,6],[8,10],[15,18]]\nExplanation: Since intervals [1,3] and [2,6] overlap, merge them into [1,6].\n\nExample 2:\nInput: intervals = [[1,4],[4,5]]\nOutput: [[1,5]]\nExplanation: Intervals [1,4] and [4,5] are considered overlapping.\n\nConstraints:\n1 <= intervals.length <= 10^4\nintervals[i].length == 2\n0 <= start_i <= end_i <= 10^4',
    hints: [
      'If the intervals were sorted by start time, any interval that overlaps another would be adjacent to it in the sorted order.',
      'After sorting, walk through the intervals once and keep a running "current merged interval"; extend its end when the next interval starts before that end.',
      'Two intervals overlap when the next start is <= the current end. Merging means taking the max of the two ends.',
    ],
    intuition:
      'The thing that trips me up at first is that overlapping intervals can be anywhere in the input - [1,3] might overlap with something listed much later. My naive instinct is to repeatedly compare every interval to every other and merge any pair that overlaps, looping until nothing changes. That is correct but clearly does a ton of redundant comparisons. The key realization is that if I first sort the intervals by their start value, then any group of intervals that should be merged together becomes contiguous - they line up next to each other. Once sorted, I only ever need to compare each interval to the last merged interval I have built so far. If the current interval starts at or before the end of that last merged interval, they overlap, and I just stretch the merged end to the max of the two ends. Otherwise there is a gap, so I close off the current merged interval and start a new one. Sorting turns a messy all-pairs problem into a clean single sweep.',
    walkthrough:
      'Brute force: repeatedly scan the list looking for any two intervals that overlap; when found, replace them with their merged interval and restart. Keep looping until a full pass makes no merges. Each pass is O(n^2) and we may need many passes, so it is slow.\n\nOptimal: first sort intervals by start ascending. Initialize merged with the first interval. For each subsequent interval current, compare current[0] (its start) with the end of the last interval in merged. If current[0] <= last_end, they overlap, so set the last merged interval end to max(last_end, current[1]). Otherwise there is no overlap, so append current as a new entry in merged. Return merged at the end.',
    complexityAnalysis:
      'Brute force: Time O(n^3) in the worst case - each merge pass is O(n^2) to find an overlapping pair and we may run up to O(n) passes; Space O(n) for the working list.\n\nOptimal: Time O(n log n) dominated by the initial sort, followed by a single O(n) sweep; Space O(n) for the output list (or O(log n) to O(n) for the sort depending on implementation).',
    solutions: {
      python: `class Solution:
    def merge(self, intervals):
        # Brute force: repeatedly merge any overlapping pair until stable.
        intervals = [list(iv) for iv in intervals]
        merged_something = True
        while merged_something:
            merged_something = False
            result = []
            used = [False] * len(intervals)
            for a in range(len(intervals)):
                if used[a]:
                    continue
                start, end = intervals[a]
                for b in range(a + 1, len(intervals)):
                    if used[b]:
                        continue
                    other_start, other_end = intervals[b]
                    # overlap check
                    if other_start <= end and start <= other_end:
                        start = min(start, other_start)
                        end = max(end, other_end)
                        used[b] = True
                        merged_something = True
                result.append([start, end])
            intervals = result
        return intervals


class SolutionOptimal:
    def merge(self, intervals):
        # Optimal: sort by start, then sweep merging adjacent overlaps.
        intervals.sort(key=lambda iv: iv[0])
        merged = [intervals[0]]

        for current in intervals[1:]:
            last_end = merged[-1][1]
            if current[0] <= last_end:
                # overlaps the last merged interval, extend its end
                merged[-1][1] = max(last_end, current[1])
            else:
                merged.append(current)

        return merged
`,
      java: `class Solution {
    // Brute force: repeatedly merge any overlapping pair until stable.
    public int[][] merge(int[][] intervals) {
        List<int[]> current = new ArrayList<>();
        for (int[] iv : intervals) {
            current.add(new int[] {iv[0], iv[1]});
        }

        boolean mergedSomething = true;
        while (mergedSomething) {
            mergedSomething = false;
            List<int[]> result = new ArrayList<>();
            boolean[] used = new boolean[current.size()];
            for (int a = 0; a < current.size(); a++) {
                if (used[a]) continue;
                int start = current.get(a)[0];
                int end = current.get(a)[1];
                for (int b = a + 1; b < current.size(); b++) {
                    if (used[b]) continue;
                    int otherStart = current.get(b)[0];
                    int otherEnd = current.get(b)[1];
                    if (otherStart <= end && start <= otherEnd) {
                        start = Math.min(start, otherStart);
                        end = Math.max(end, otherEnd);
                        used[b] = true;
                        mergedSomething = true;
                    }
                }
                result.add(new int[] {start, end});
            }
            current = result;
        }

        return current.toArray(new int[current.size()][]);
    }
}

class SolutionOptimal {
    // Optimal: sort by start, then sweep merging adjacent overlaps.
    public int[][] merge(int[][] intervals) {
        Arrays.sort(intervals, (x, y) -> Integer.compare(x[0], y[0]));
        List<int[]> merged = new ArrayList<>();
        merged.add(new int[] {intervals[0][0], intervals[0][1]});

        for (int i = 1; i < intervals.length; i++) {
            int[] current = intervals[i];
            int[] last = merged.get(merged.size() - 1);
            if (current[0] <= last[1]) {
                last[1] = Math.max(last[1], current[1]);
            } else {
                merged.add(new int[] {current[0], current[1]});
            }
        }

        return merged.toArray(new int[merged.size()][]);
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: repeatedly merge any overlapping pair until stable.
    vector<vector<int>> merge(vector<vector<int>>& intervals) {
        vector<vector<int>> current = intervals;
        bool mergedSomething = true;
        while (mergedSomething) {
            mergedSomething = false;
            vector<vector<int>> result;
            vector<bool> used(current.size(), false);
            for (int a = 0; a < (int)current.size(); a++) {
                if (used[a]) continue;
                int start = current[a][0];
                int end = current[a][1];
                for (int b = a + 1; b < (int)current.size(); b++) {
                    if (used[b]) continue;
                    int otherStart = current[b][0];
                    int otherEnd = current[b][1];
                    if (otherStart <= end && start <= otherEnd) {
                        start = min(start, otherStart);
                        end = max(end, otherEnd);
                        used[b] = true;
                        mergedSomething = true;
                    }
                }
                result.push_back({start, end});
            }
            current = result;
        }
        return current;
    }
};

class SolutionOptimal {
public:
    // Optimal: sort by start, then sweep merging adjacent overlaps.
    vector<vector<int>> merge(vector<vector<int>>& intervals) {
        sort(intervals.begin(), intervals.end(),
             [](const vector<int>& x, const vector<int>& y) {
                 return x[0] < y[0];
             });

        vector<vector<int>> merged;
        merged.push_back(intervals[0]);

        for (int i = 1; i < (int)intervals.size(); i++) {
            vector<int>& current = intervals[i];
            if (current[0] <= merged.back()[1]) {
                merged.back()[1] = max(merged.back()[1], current[1]);
            } else {
                merged.push_back(current);
            }
        }

        return merged;
    }
};
`,
    },
  },
  {
    problemNumber: 200,
    title: 'Number of Islands',
    slug: 'number-of-islands',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/number-of-islands',
    topics: ['Array', 'Depth-First Search', 'Breadth-First Search', 'Union Find', 'Matrix'],
    companies: ['Tesla'],
    frequency: 89.6,
    acceptanceRate: 0.6232,
    problemStatement:
      'Given an m x n 2D binary grid grid which represents a map of \'1\'s (land) and \'0\'s (water), return the number of islands.\n\nAn island is surrounded by water and is formed by connecting adjacent lands horizontally or vertically. You may assume all four edges of the grid are all surrounded by water.\n\nExample 1:\nInput: grid = [\n  ["1","1","1","1","0"],\n  ["1","1","0","1","0"],\n  ["1","1","0","0","0"],\n  ["0","0","0","0","0"]\n]\nOutput: 1\n\nExample 2:\nInput: grid = [\n  ["1","1","0","0","0"],\n  ["1","1","0","0","0"],\n  ["0","0","1","0","0"],\n  ["0","0","0","1","1"]\n]\nOutput: 3\n\nConstraints:\nm == grid.length\nn == grid[i].length\n1 <= m, n <= 300\ngrid[i][j] is \'0\' or \'1\'.',
    hints: [
      'Each time you find a piece of land that has not been visited yet, it must be the start of a new island.',
      'From that starting cell, flood the entire connected blob of land (up/down/left/right) so you do not count any of its cells again.',
      'You can flood with DFS or BFS; marking visited cells (or overwriting them to \'0\') prevents recounting.',
    ],
    intuition:
      'When I look at this grid, the count I want is really the number of distinct connected blobs of land. My first instinct is to think about how to avoid counting the same island twice. The clean idea is: scan the grid cell by cell, and the very first time I touch a land cell that I have not seen before, I know I have discovered a brand new island, so I increment my counter. Then, crucially, I "sink" that entire island - I flood-fill outward from that cell to every connected land cell and mark them all as visited (or just overwrite them to water). That way, when my scan later reaches those cells, they are no longer land and will not trigger another count. The flood fill is just a graph traversal where the neighbors of a cell are its four orthogonal neighbors that are also land. Whether I use DFS or BFS does not change the count - it only changes how I walk the blob. The realization that "one new unvisited land cell = exactly one new island, then erase the whole blob" is what makes this clean.',
    walkthrough:
      'A genuinely naive approach a student might reach for is Union-Find done clumsily, but the simplest naive version is repeated scanning: this brute force keeps a visited matrix and, for each land cell, does a fresh BFS to mark its component, recounting carelessly - to keep it honestly naive here I implement the brute force as a BFS flood that uses an explicit visited matrix rather than mutating the grid, and the optimal mutates the grid in place to save space.\n\nBrute force (BFS with a separate visited grid): keep a 2D visited array. Scan every cell; when we find a \'1\' that is not visited, increment island_count and run a BFS from it, enqueuing unvisited land neighbors and marking them visited, until the queue drains.\n\nOptimal (DFS, mutate in place): scan every cell; when grid[r][c] == \'1\', increment island_count and call a recursive sink function that sets the cell to \'0\' and recurses into its four neighbors that are still \'1\'. Overwriting to \'0\' is our visited marker, so no extra matrix is needed.',
    complexityAnalysis:
      'Brute force (BFS + visited matrix): Time O(m * n) because every cell is enqueued and dequeued at most once; Space O(m * n) for the visited matrix plus the BFS queue in the worst case.\n\nOptimal (in-place DFS): Time O(m * n) since each cell is visited a constant number of times; Space O(m * n) in the worst case for the recursion stack (a grid that is entirely land), but no separate visited matrix is needed.',
    solutions: {
      python: `from collections import deque


class Solution:
    def numIslands(self, grid):
        # Brute force: BFS flood with a separate visited matrix.
        if not grid:
            return 0
        rows = len(grid)
        cols = len(grid[0])
        visited = [[False] * cols for _ in range(rows)]
        island_count = 0

        for r in range(rows):
            for c in range(cols):
                if grid[r][c] == '1' and not visited[r][c]:
                    island_count += 1
                    queue = deque([(r, c)])
                    visited[r][c] = True
                    while queue:
                        cr, cc = queue.popleft()
                        for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                            nr, nc = cr + dr, cc + dc
                            if 0 <= nr < rows and 0 <= nc < cols:
                                if grid[nr][nc] == '1' and not visited[nr][nc]:
                                    visited[nr][nc] = True
                                    queue.append((nr, nc))

        return island_count


class SolutionOptimal:
    def numIslands(self, grid):
        # Optimal: DFS that sinks each island in place (no visited matrix).
        if not grid:
            return 0
        rows = len(grid)
        cols = len(grid[0])
        island_count = 0

        def sink(r, c):
            if r < 0 or r >= rows or c < 0 or c >= cols:
                return
            if grid[r][c] != '1':
                return
            grid[r][c] = '0'  # mark as visited by turning to water
            sink(r - 1, c)
            sink(r + 1, c)
            sink(r, c - 1)
            sink(r, c + 1)

        for r in range(rows):
            for c in range(cols):
                if grid[r][c] == '1':
                    island_count += 1
                    sink(r, c)

        return island_count
`,
      java: `class Solution {
    // Brute force: BFS flood with a separate visited matrix.
    public int numIslands(char[][] grid) {
        int rows = grid.length;
        int cols = grid[0].length;
        boolean[][] visited = new boolean[rows][cols];
        int islandCount = 0;
        int[][] directions = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}};

        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (grid[r][c] == '1' && !visited[r][c]) {
                    islandCount++;
                    Queue<int[]> queue = new LinkedList<>();
                    queue.add(new int[] {r, c});
                    visited[r][c] = true;
                    while (!queue.isEmpty()) {
                        int[] cell = queue.poll();
                        for (int[] d : directions) {
                            int nr = cell[0] + d[0];
                            int nc = cell[1] + d[1];
                            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols
                                    && grid[nr][nc] == '1' && !visited[nr][nc]) {
                                visited[nr][nc] = true;
                                queue.add(new int[] {nr, nc});
                            }
                        }
                    }
                }
            }
        }

        return islandCount;
    }
}

class SolutionOptimal {
    // Optimal: DFS that sinks each island in place (no visited matrix).
    public int numIslands(char[][] grid) {
        int rows = grid.length;
        int cols = grid[0].length;
        int islandCount = 0;

        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (grid[r][c] == '1') {
                    islandCount++;
                    sink(grid, r, c, rows, cols);
                }
            }
        }

        return islandCount;
    }

    private void sink(char[][] grid, int r, int c, int rows, int cols) {
        if (r < 0 || r >= rows || c < 0 || c >= cols) {
            return;
        }
        if (grid[r][c] != '1') {
            return;
        }
        grid[r][c] = '0';
        sink(grid, r - 1, c, rows, cols);
        sink(grid, r + 1, c, rows, cols);
        sink(grid, r, c - 1, rows, cols);
        sink(grid, r, c + 1, rows, cols);
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: BFS flood with a separate visited matrix.
    int numIslands(vector<vector<char>>& grid) {
        int rows = grid.size();
        int cols = grid[0].size();
        vector<vector<bool>> visited(rows, vector<bool>(cols, false));
        int islandCount = 0;
        int directions[4][2] = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}};

        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (grid[r][c] == '1' && !visited[r][c]) {
                    islandCount++;
                    queue<pair<int, int>> q;
                    q.push({r, c});
                    visited[r][c] = true;
                    while (!q.empty()) {
                        auto cell = q.front();
                        q.pop();
                        for (auto& d : directions) {
                            int nr = cell.first + d[0];
                            int nc = cell.second + d[1];
                            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols
                                    && grid[nr][nc] == '1' && !visited[nr][nc]) {
                                visited[nr][nc] = true;
                                q.push({nr, nc});
                            }
                        }
                    }
                }
            }
        }

        return islandCount;
    }
};

class SolutionOptimal {
public:
    // Optimal: DFS that sinks each island in place (no visited matrix).
    int numIslands(vector<vector<char>>& grid) {
        int rows = grid.size();
        int cols = grid[0].size();
        int islandCount = 0;

        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (grid[r][c] == '1') {
                    islandCount++;
                    sink(grid, r, c, rows, cols);
                }
            }
        }

        return islandCount;
    }

private:
    void sink(vector<vector<char>>& grid, int r, int c, int rows, int cols) {
        if (r < 0 || r >= rows || c < 0 || c >= cols) return;
        if (grid[r][c] != '1') return;
        grid[r][c] = '0';
        sink(grid, r - 1, c, rows, cols);
        sink(grid, r + 1, c, rows, cols);
        sink(grid, r, c - 1, rows, cols);
        sink(grid, r, c + 1, rows, cols);
    }
};
`,
    },
  },
  {
    problemNumber: 622,
    title: 'Design Circular Queue',
    slug: 'design-circular-queue',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/design-circular-queue',
    topics: ['Array', 'Linked List', 'Design', 'Queue'],
    companies: ['Tesla'],
    frequency: 86.1,
    acceptanceRate: 0.5264,
    problemStatement:
      'Design your implementation of the circular queue. The circular queue is a linear data structure in which the operations are performed based on FIFO (First In First Out) principle, and the last position is connected back to the first position to make a circle. It is also called "Ring Buffer".\n\nImplement the MyCircularQueue class:\n- MyCircularQueue(k) Initializes the object with the size of the queue to be k.\n- int Front() Gets the front item from the queue. If the queue is empty, return -1.\n- int Rear() Gets the last item from the queue. If the queue is empty, return -1.\n- boolean enQueue(int value) Inserts an element into the circular queue. Return true if the operation is successful.\n- boolean deQueue() Deletes an element from the circular queue. Return true if the operation is successful.\n- boolean isEmpty() Checks whether the circular queue is empty or not.\n- boolean isFull() Checks whether the circular queue is full or not.\n\nYou must solve the problem without using the built-in queue data structure in your programming language.\n\nExample 1:\nInput\n["MyCircularQueue", "enQueue", "enQueue", "enQueue", "enQueue", "Rear", "isFull", "deQueue", "enQueue", "Rear"]\n[[3], [1], [2], [3], [4], [], [], [], [4], []]\nOutput\n[null, true, true, true, false, 3, true, true, true, 4]\n\nConstraints:\n1 <= k <= 1000\n0 <= value <= 1000\nAt most 3000 calls will be made to enQueue, deQueue, Front, Rear, isEmpty, and isFull.',
    hints: [
      'A fixed-size array is the natural backing store; the trick is reusing slots when the queue wraps around the end.',
      'Track a head index and a count (or a tail index). Use modular arithmetic to wrap indices back to the start of the array.',
      'isEmpty is count == 0; isFull is count == capacity. The rear slot is (head + count - 1) % capacity.',
    ],
    intuition:
      'My first instinct for a queue is to use a dynamic list and just append on enqueue and pop from the front on dequeue. That is simple and correct, but popping from the front of an array shifts every remaining element, which is O(n), and the problem clearly wants a fixed-capacity ring buffer. The key realization is that I do not actually need to move data when I dequeue - I just need to remember where the logical front is. So I keep a fixed array of size k, an index head pointing at the front element, and a count of how many elements are currently stored. Enqueue writes to the slot just past the last element, which is (head + count) % capacity, and bumps count. Dequeue just advances head to (head + 1) % capacity and decrements count. The modulo is what makes the array behave like a circle: when an index runs off the end, it wraps back to position 0 and reuses slots that earlier dequeues freed up. That gives me O(1) for every operation with no shifting.',
    walkthrough:
      'Brute force (naive list shifting): back the queue with a Python list / ArrayList / vector, enqueue by appending if size < capacity, dequeue by removing element 0 (which shifts everything left). Front and Rear read index 0 and the last index. This is simple but dequeue is O(n) because of the shift.\n\nOptimal (fixed array + head + count): allocate a fixed array data of length capacity. Keep head (index of the front) and count (number of stored items). enQueue checks isFull; if not, writes value at (head + count) % capacity and increments count. deQueue checks isEmpty; if not, advances head to (head + 1) % capacity and decrements count. Front returns data[head]; Rear returns data[(head + count - 1) % capacity]. isEmpty is count == 0, isFull is count == capacity. Every operation is O(1) with no element movement.',
    complexityAnalysis:
      'Brute force (list with front removal): enQueue is amortized O(1) but deQueue is O(n) because removing the first element shifts all remaining elements; Space O(k).\n\nOptimal (ring buffer): every operation - enQueue, deQueue, Front, Rear, isEmpty, isFull - is O(1) because we only update indices and a counter using modular arithmetic; Space O(k) for the fixed backing array.',
    solutions: {
      python: `class Solution:
    # Brute force: back the queue with a list and remove from the front.
    def __init__(self, k: int):
        self.capacity = k
        self.data = []

    def enQueue(self, value: int) -> bool:
        if self.isFull():
            return False
        self.data.append(value)
        return True

    def deQueue(self) -> bool:
        if self.isEmpty():
            return False
        self.data.pop(0)  # O(n) shift of remaining elements
        return True

    def Front(self) -> int:
        return -1 if self.isEmpty() else self.data[0]

    def Rear(self) -> int:
        return -1 if self.isEmpty() else self.data[-1]

    def isEmpty(self) -> bool:
        return len(self.data) == 0

    def isFull(self) -> bool:
        return len(self.data) == self.capacity


class SolutionOptimal:
    # Optimal: fixed array ring buffer with head index and count.
    def __init__(self, k: int):
        self.capacity = k
        self.data = [0] * k
        self.head = 0
        self.count = 0

    def enQueue(self, value: int) -> bool:
        if self.isFull():
            return False
        tail = (self.head + self.count) % self.capacity
        self.data[tail] = value
        self.count += 1
        return True

    def deQueue(self) -> bool:
        if self.isEmpty():
            return False
        self.head = (self.head + 1) % self.capacity
        self.count -= 1
        return True

    def Front(self) -> int:
        return -1 if self.isEmpty() else self.data[self.head]

    def Rear(self) -> int:
        if self.isEmpty():
            return -1
        rear_index = (self.head + self.count - 1) % self.capacity
        return self.data[rear_index]

    def isEmpty(self) -> bool:
        return self.count == 0

    def isFull(self) -> bool:
        return self.count == self.capacity
`,
      java: `class Solution {
    // Brute force: back the queue with a list and remove from the front.
    private int capacity;
    private List<Integer> data;

    public Solution(int k) {
        this.capacity = k;
        this.data = new ArrayList<>();
    }

    public boolean enQueue(int value) {
        if (isFull()) return false;
        data.add(value);
        return true;
    }

    public boolean deQueue() {
        if (isEmpty()) return false;
        data.remove(0); // O(n) shift of remaining elements
        return true;
    }

    public int Front() {
        return isEmpty() ? -1 : data.get(0);
    }

    public int Rear() {
        return isEmpty() ? -1 : data.get(data.size() - 1);
    }

    public boolean isEmpty() {
        return data.isEmpty();
    }

    public boolean isFull() {
        return data.size() == capacity;
    }
}

class SolutionOptimal {
    // Optimal: fixed array ring buffer with head index and count.
    private int[] data;
    private int capacity;
    private int head;
    private int count;

    public SolutionOptimal(int k) {
        this.capacity = k;
        this.data = new int[k];
        this.head = 0;
        this.count = 0;
    }

    public boolean enQueue(int value) {
        if (isFull()) return false;
        int tail = (head + count) % capacity;
        data[tail] = value;
        count++;
        return true;
    }

    public boolean deQueue() {
        if (isEmpty()) return false;
        head = (head + 1) % capacity;
        count--;
        return true;
    }

    public int Front() {
        return isEmpty() ? -1 : data[head];
    }

    public int Rear() {
        if (isEmpty()) return -1;
        int rearIndex = (head + count - 1) % capacity;
        return data[rearIndex];
    }

    public boolean isEmpty() {
        return count == 0;
    }

    public boolean isFull() {
        return count == capacity;
    }
}
`,
      cpp: `class Solution {
    // Brute force: back the queue with a vector and erase from the front.
private:
    int capacity;
    vector<int> data;

public:
    Solution(int k) {
        capacity = k;
    }

    bool enQueue(int value) {
        if (isFull()) return false;
        data.push_back(value);
        return true;
    }

    bool deQueue() {
        if (isEmpty()) return false;
        data.erase(data.begin()); // O(n) shift of remaining elements
        return true;
    }

    int Front() {
        return isEmpty() ? -1 : data.front();
    }

    int Rear() {
        return isEmpty() ? -1 : data.back();
    }

    bool isEmpty() {
        return data.empty();
    }

    bool isFull() {
        return (int)data.size() == capacity;
    }
};

class SolutionOptimal {
    // Optimal: fixed array ring buffer with head index and count.
private:
    vector<int> data;
    int capacity;
    int head;
    int count;

public:
    SolutionOptimal(int k) : data(k, 0), capacity(k), head(0), count(0) {}

    bool enQueue(int value) {
        if (isFull()) return false;
        int tail = (head + count) % capacity;
        data[tail] = value;
        count++;
        return true;
    }

    bool deQueue() {
        if (isEmpty()) return false;
        head = (head + 1) % capacity;
        count--;
        return true;
    }

    int Front() {
        return isEmpty() ? -1 : data[head];
    }

    int Rear() {
        if (isEmpty()) return -1;
        int rearIndex = (head + count - 1) % capacity;
        return data[rearIndex];
    }

    bool isEmpty() {
        return count == 0;
    }

    bool isFull() {
        return count == capacity;
    }
};
`,
    },
  },
  {
    problemNumber: 1117,
    title: 'Building H2O',
    slug: 'building-h2o',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/building-h2o',
    topics: ['Concurrency'],
    companies: ['Tesla'],
    frequency: 86.1,
    acceptanceRate: 0.5759,
    problemStatement:
      'There are two kinds of threads: oxygen and hydrogen. Your goal is to group these threads to form water molecules.\n\nThere is a barrier where each thread has to wait until a complete molecule can be formed. Hydrogen and oxygen threads will be given releaseHydrogen and releaseOxygen methods respectively, which will allow them to pass the barrier. These threads should pass the barrier in groups of three, and they must immediately bond with each other to form a water molecule. You must guarantee that all the threads from one molecule bond before any other threads from the next molecule do.\n\nIn other words:\n- If an oxygen thread arrives at the barrier when no hydrogen threads are present, it must wait for two hydrogen threads.\n- If a hydrogen thread arrives at the barrier when no other threads are present, it must wait for an oxygen thread and another hydrogen thread.\n\nWe do not have to worry about matching the threads up explicitly; the threads do not necessarily know which other threads they are paired up with. The key is that threads pass the barrier in complete sets; thus, if we examine the sequence of threads that bond and divide them into groups of three, each group should contain one oxygen and two hydrogen threads.\n\nWrite synchronization code for oxygen and hydrogen molecules that enforces these constraints.\n\nExample 1:\nInput: water = "HOH"\nOutput: "HHO"\nExplanation: "HOH" and "OHH" are also valid answers.\n\nExample 2:\nInput: water = "OOHHHH"\nOutput: "HHOHHO"\nExplanation: "HOHHHO", "OHHHHO", and several others are valid answers.\n\nConstraints:\n3 * n == water.length\n1 <= n <= 20\nwater[i] is either \'H\' or \'O\'.\nThere will be 2 * n \'H\' in water.',
    hints: [
      'You need to allow exactly two hydrogen threads and one oxygen thread to proceed before any thread from the next molecule.',
      'Two semaphores - one permitting up to 2 hydrogens, one permitting 1 oxygen - control how many of each kind may pass at once.',
      'A barrier (CyclicBarrier of size 3, or a count plus a lock) ensures all three threads of a molecule meet before any is released and the permits are reset for the next molecule.',
    ],
    intuition:
      'The way I read this, I need to release threads in exact bundles of one O and two H, and never let a thread from the next molecule sneak through before the current trio is complete. My first, naive instinct is to put one big lock around everything and manually count how many H and O have arrived, releasing when I have 2 H and 1 O - that works but it is easy to get the bookkeeping wrong and it serializes a lot. The cleaner mental model is to use semaphores as "permit budgets": a hydrogen semaphore that starts with 2 permits (so at most two H pass per molecule) and an oxygen semaphore that starts with 1 permit (so at most one O passes). Each thread acquires its kind of permit before releasing, which naturally caps the composition of a molecule. The remaining piece is making sure all three actually meet before the next molecule starts - that is exactly what a barrier of size 3 does: each thread waits at the barrier until three have gathered, then they all proceed together and I refill the permits for the next round. The barrier is the key realization that turns "right counts" into "right grouping."',
    walkthrough:
      'Brute force (single lock with manual counters): use one lock and a condition variable, plus counters for waiting hydrogen and oxygen. Each thread takes the lock, waits on the condition until its release is allowed given current counts, performs its release, updates counts, and signals others. This is correct but coarse-grained: nearly everything happens under one lock and the condition logic to enforce 2H+1O grouping is intricate and easy to get wrong.\n\nOptimal (two semaphores + barrier): create hydrogenSemaphore with 2 permits, oxygenSemaphore with 1 permit, and a barrier that trips when 3 threads await. In hydrogen, acquire hydrogenSemaphore, wait on the barrier (so all three of the molecule meet), call releaseHydrogen, then release hydrogenSemaphore so the next molecule can reuse the permit. In oxygen, acquire oxygenSemaphore, wait on the barrier, call releaseOxygen, then release oxygenSemaphore. The semaphores cap each molecule to 1 O + 2 H, and the size-3 barrier guarantees no thread of the next molecule bonds before the current three have met.',
    complexityAnalysis:
      'Brute force (single lock + condition): each releaseHydrogen / releaseOxygen does O(1) work under the lock, but the global lock serializes threads heavily and the condition re-checks add contention; Space O(1) for the counters.\n\nOptimal (semaphores + barrier): each thread performs O(1) synchronization operations - one acquire, one barrier wait, one release; Space O(1) for the two semaphores and the single barrier, independent of the number of molecules.',
    solutions: {
      python: `import threading


class Solution:
    # Brute force: a single lock plus a condition variable with manual counts.
    def __init__(self):
        self.lock = threading.Condition()
        self.hydrogen_released = 0
        self.oxygen_released = 0

    def hydrogen(self, releaseHydrogen) -> None:
        with self.lock:
            # wait until this molecule still needs a hydrogen
            while self.hydrogen_released >= 2 and self.oxygen_released == 0:
                self.lock.wait()
            while self.hydrogen_released == 2:
                self.lock.wait()
            releaseHydrogen()
            self.hydrogen_released += 1
            self._maybe_reset()
            self.lock.notify_all()

    def oxygen(self, releaseOxygen) -> None:
        with self.lock:
            while self.oxygen_released == 1:
                self.lock.wait()
            releaseOxygen()
            self.oxygen_released += 1
            self._maybe_reset()
            self.lock.notify_all()

    def _maybe_reset(self):
        if self.hydrogen_released == 2 and self.oxygen_released == 1:
            self.hydrogen_released = 0
            self.oxygen_released = 0


class SolutionOptimal:
    # Optimal: two semaphores cap the composition; a barrier groups the trio.
    def __init__(self):
        self.hydrogen_semaphore = threading.Semaphore(2)
        self.oxygen_semaphore = threading.Semaphore(1)
        self.barrier = threading.Barrier(3)

    def hydrogen(self, releaseHydrogen) -> None:
        self.hydrogen_semaphore.acquire()
        self.barrier.wait()       # all three of the molecule meet here
        releaseHydrogen()
        self.hydrogen_semaphore.release()

    def oxygen(self, releaseOxygen) -> None:
        self.oxygen_semaphore.acquire()
        self.barrier.wait()       # all three of the molecule meet here
        releaseOxygen()
        self.oxygen_semaphore.release()
`,
      java: `class Solution {
    // Brute force: a single lock plus condition with manual counts.
    private final Object lock = new Object();
    private int hydrogenReleased = 0;
    private int oxygenReleased = 0;

    public Solution() {}

    public void hydrogen(Runnable releaseHydrogen) throws InterruptedException {
        synchronized (lock) {
            while (hydrogenReleased == 2) {
                lock.wait();
            }
            releaseHydrogen.run();
            hydrogenReleased++;
            maybeReset();
            lock.notifyAll();
        }
    }

    public void oxygen(Runnable releaseOxygen) throws InterruptedException {
        synchronized (lock) {
            while (oxygenReleased == 1) {
                lock.wait();
            }
            releaseOxygen.run();
            oxygenReleased++;
            maybeReset();
            lock.notifyAll();
        }
    }

    private void maybeReset() {
        if (hydrogenReleased == 2 && oxygenReleased == 1) {
            hydrogenReleased = 0;
            oxygenReleased = 0;
        }
    }
}

class SolutionOptimal {
    // Optimal: two semaphores cap composition; a CyclicBarrier groups the trio.
    private final Semaphore hydrogenSemaphore = new Semaphore(2);
    private final Semaphore oxygenSemaphore = new Semaphore(1);
    private final CyclicBarrier barrier = new CyclicBarrier(3);

    public SolutionOptimal() {}

    public void hydrogen(Runnable releaseHydrogen) throws InterruptedException {
        hydrogenSemaphore.acquire();
        try {
            barrier.await();
        } catch (Exception e) {
            Thread.currentThread().interrupt();
        }
        releaseHydrogen.run();
        hydrogenSemaphore.release();
    }

    public void oxygen(Runnable releaseOxygen) throws InterruptedException {
        oxygenSemaphore.acquire();
        try {
            barrier.await();
        } catch (Exception e) {
            Thread.currentThread().interrupt();
        }
        releaseOxygen.run();
        oxygenSemaphore.release();
    }
}
`,
      cpp: `class Solution {
    // Brute force: a single mutex plus condition variable with manual counts.
private:
    mutex lock;
    condition_variable cv;
    int hydrogenReleased = 0;
    int oxygenReleased = 0;

    void maybeReset() {
        if (hydrogenReleased == 2 && oxygenReleased == 1) {
            hydrogenReleased = 0;
            oxygenReleased = 0;
        }
    }

public:
    Solution() {}

    void hydrogen(function<void()> releaseHydrogen) {
        unique_lock<mutex> guard(lock);
        cv.wait(guard, [this]() { return hydrogenReleased < 2; });
        releaseHydrogen();
        hydrogenReleased++;
        maybeReset();
        cv.notify_all();
    }

    void oxygen(function<void()> releaseOxygen) {
        unique_lock<mutex> guard(lock);
        cv.wait(guard, [this]() { return oxygenReleased < 1; });
        releaseOxygen();
        oxygenReleased++;
        maybeReset();
        cv.notify_all();
    }
};

class SolutionOptimal {
    // Optimal: two counting semaphores cap composition; a barrier groups three.
private:
    counting_semaphore<2> hydrogenSemaphore{2};
    counting_semaphore<1> oxygenSemaphore{1};

    // Simple reusable barrier of size 3.
    mutex barrierMutex;
    condition_variable barrierCv;
    int arrived = 0;
    int generation = 0;

    void barrierWait() {
        unique_lock<mutex> guard(barrierMutex);
        int myGeneration = generation;
        arrived++;
        if (arrived == 3) {
            arrived = 0;
            generation++;
            barrierCv.notify_all();
        } else {
            barrierCv.wait(guard, [this, myGeneration]() {
                return generation != myGeneration;
            });
        }
    }

public:
    SolutionOptimal() {}

    void hydrogen(function<void()> releaseHydrogen) {
        hydrogenSemaphore.acquire();
        barrierWait();
        releaseHydrogen();
        hydrogenSemaphore.release();
    }

    void oxygen(function<void()> releaseOxygen) {
        oxygenSemaphore.acquire();
        barrierWait();
        releaseOxygen();
        oxygenSemaphore.release();
    }
};
`,
    },
  },
  {
    problemNumber: 17,
    title: 'Letter Combinations of a Phone Number',
    slug: 'letter-combinations-of-a-phone-number',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/letter-combinations-of-a-phone-number',
    topics: ['Hash Table', 'String', 'Backtracking'],
    companies: ['Tesla'],
    frequency: 82.2,
    acceptanceRate: 0.6386,
    problemStatement:
      'Given a string containing digits from 2-9 inclusive, return all possible letter combinations that the number could represent. Return the answer in any order.\n\nA mapping of digits to letters (just like on the telephone buttons) is given below. Note that 1 does not map to any letters.\n\n2 -> "abc"\n3 -> "def"\n4 -> "ghi"\n5 -> "jkl"\n6 -> "mno"\n7 -> "pqrs"\n8 -> "tuv"\n9 -> "wxyz"\n\nExample 1:\nInput: digits = "23"\nOutput: ["ad","ae","af","bd","be","bf","cd","ce","cf"]\n\nExample 2:\nInput: digits = ""\nOutput: []\n\nExample 3:\nInput: digits = "2"\nOutput: ["a","b","c"]\n\nConstraints:\n0 <= digits.length <= 4\ndigits[i] is a digit in the range [\'2\', \'9\'].',
    hints: [
      'Each digit independently multiplies the number of combinations by the count of letters it maps to.',
      'Build the combinations one digit at a time: take every combination built so far and extend it with every letter of the next digit.',
      'Backtracking (DFS) builds each combination character by character and backtracks once it reaches the full length.',
    ],
    intuition:
      'This is the classic "generate the cartesian product" problem in disguise. Each digit gives me a small set of letters, and a valid combination picks exactly one letter from each digit\'s set, in order. My first instinct is an iterative build-up: start with a list containing the empty string, and for each digit, replace that list with a new list where every existing partial string is extended by each possible letter of the current digit. That is essentially computing the cross product step by step, and it is easy to reason about. The more idiomatic way for this kind of "make all sequences of choices" problem is backtracking: I walk the digits with an index, and at each level I try every letter the current digit maps to, append it to a running path, recurse to the next digit, then pop it off to try the next letter. The realization that ties it together is that there is no pruning to do here - every combination is valid - so backtracking is really just a clean recursive way to enumerate the same cross product, building each result one character at a time without rebuilding whole lists.',
    walkthrough:
      'Brute force (iterative cross product): keep a list combinations initialized to [""]. For each digit in digits, look up its letters, and build a brand new list by taking every string already in combinations and appending each letter; then replace combinations with that new list. After processing all digits, combinations holds every result. It works but it rebuilds the entire list at each step.\n\nOptimal (backtracking): map each digit to its letters. Use a recursive helper backtrack(index, path): if index equals the length of digits, the path is a finished combination, so add path to results and return. Otherwise, for each letter that digits[index] maps to, append it to path, recurse with index + 1, then remove it (backtrack) to try the next letter. Guard the empty-input case by returning an empty list when digits is empty.',
    complexityAnalysis:
      'Both approaches: Time O(4^n * n) where n is the number of digits - there are up to 4^n combinations (digits 7 and 9 map to 4 letters) and assembling each finished string of length n costs O(n).\n\nBrute force space: O(4^n * n) because it materializes every intermediate list of partial strings. Optimal backtracking space: O(n) for the recursion depth and the path buffer, excluding the O(4^n * n) needed to store the final output that the problem requires.',
    solutions: {
      python: `class Solution:
    def letterCombinations(self, digits: str):
        # Brute force: iteratively build the cross product of letter sets.
        if not digits:
            return []
        digit_to_letters = {
            '2': 'abc', '3': 'def', '4': 'ghi', '5': 'jkl',
            '6': 'mno', '7': 'pqrs', '8': 'tuv', '9': 'wxyz',
        }

        combinations = ['']
        for digit in digits:
            letters = digit_to_letters[digit]
            next_combinations = []
            for partial in combinations:
                for letter in letters:
                    next_combinations.append(partial + letter)
            combinations = next_combinations

        return combinations


class SolutionOptimal:
    def letterCombinations(self, digits: str):
        # Optimal: backtracking, building each combination character by character.
        if not digits:
            return []
        digit_to_letters = {
            '2': 'abc', '3': 'def', '4': 'ghi', '5': 'jkl',
            '6': 'mno', '7': 'pqrs', '8': 'tuv', '9': 'wxyz',
        }
        results = []
        path = []

        def backtrack(index):
            if index == len(digits):
                results.append(''.join(path))
                return
            for letter in digit_to_letters[digits[index]]:
                path.append(letter)
                backtrack(index + 1)
                path.pop()

        backtrack(0)
        return results
`,
      java: `class Solution {
    // Brute force: iteratively build the cross product of letter sets.
    public List<String> letterCombinations(String digits) {
        List<String> combinations = new ArrayList<>();
        if (digits.isEmpty()) {
            return combinations;
        }
        String[] digitToLetters = {
            "", "", "abc", "def", "ghi", "jkl", "mno", "pqrs", "tuv", "wxyz"
        };

        combinations.add("");
        for (int i = 0; i < digits.length(); i++) {
            String letters = digitToLetters[digits.charAt(i) - '0'];
            List<String> next = new ArrayList<>();
            for (String partial : combinations) {
                for (char letter : letters.toCharArray()) {
                    next.add(partial + letter);
                }
            }
            combinations = next;
        }

        return combinations;
    }
}

class SolutionOptimal {
    // Optimal: backtracking, building each combination character by character.
    private String[] digitToLetters = {
        "", "", "abc", "def", "ghi", "jkl", "mno", "pqrs", "tuv", "wxyz"
    };

    public List<String> letterCombinations(String digits) {
        List<String> results = new ArrayList<>();
        if (digits.isEmpty()) {
            return results;
        }
        backtrack(digits, 0, new StringBuilder(), results);
        return results;
    }

    private void backtrack(String digits, int index, StringBuilder path, List<String> results) {
        if (index == digits.length()) {
            results.add(path.toString());
            return;
        }
        String letters = digitToLetters[digits.charAt(index) - '0'];
        for (char letter : letters.toCharArray()) {
            path.append(letter);
            backtrack(digits, index + 1, path, results);
            path.deleteCharAt(path.length() - 1);
        }
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: iteratively build the cross product of letter sets.
    vector<string> letterCombinations(string digits) {
        vector<string> combinations;
        if (digits.empty()) {
            return combinations;
        }
        vector<string> digitToLetters = {
            "", "", "abc", "def", "ghi", "jkl", "mno", "pqrs", "tuv", "wxyz"
        };

        combinations.push_back("");
        for (char d : digits) {
            string letters = digitToLetters[d - '0'];
            vector<string> next;
            for (const string& partial : combinations) {
                for (char letter : letters) {
                    next.push_back(partial + letter);
                }
            }
            combinations = next;
        }

        return combinations;
    }
};

class SolutionOptimal {
public:
    // Optimal: backtracking, building each combination character by character.
    vector<string> letterCombinations(string digits) {
        vector<string> results;
        if (digits.empty()) {
            return results;
        }
        vector<string> digitToLetters = {
            "", "", "abc", "def", "ghi", "jkl", "mno", "pqrs", "tuv", "wxyz"
        };
        string path;
        backtrack(digits, 0, path, digitToLetters, results);
        return results;
    }

private:
    void backtrack(const string& digits, int index, string& path,
                   const vector<string>& digitToLetters, vector<string>& results) {
        if (index == (int)digits.size()) {
            results.push_back(path);
            return;
        }
        const string& letters = digitToLetters[digits[index] - '0'];
        for (char letter : letters) {
            path.push_back(letter);
            backtrack(digits, index + 1, path, digitToLetters, results);
            path.pop_back();
        }
    }
};
`,
    },
  },
  {
    problemNumber: 20,
    title: 'Valid Parentheses',
    slug: 'valid-parentheses',
    difficulty: 'EASY',
    link: 'https://leetcode.com/problems/valid-parentheses',
    topics: ['String', 'Stack'],
    companies: ['Tesla'],
    frequency: 82.2,
    acceptanceRate: 0.4232,
    problemStatement:
      'Given a string s containing just the characters \'(\', \')\', \'{\', \'}\', \'[\' and \']\', determine if the input string is valid.\n\nAn input string is valid if:\n1. Open brackets must be closed by the same type of brackets.\n2. Open brackets must be closed in the correct order.\n3. Every close bracket has a corresponding open bracket of the same type.\n\nExample 1:\nInput: s = "()"\nOutput: true\n\nExample 2:\nInput: s = "()[]{}"\nOutput: true\n\nExample 3:\nInput: s = "(]"\nOutput: false\n\nExample 4:\nInput: s = "([])"\nOutput: true\n\nConstraints:\n1 <= s.length <= 10^4\ns consists of parentheses only \'()[]{}\'.',
    hints: [
      'The most recently opened bracket must be the first one to close - that is last-in-first-out behavior.',
      'Push every opening bracket onto a stack; when you see a closing bracket, it must match the bracket on top of the stack.',
      'At the end, the stack must be empty - any leftover opening brackets mean the string is invalid.',
    ],
    intuition:
      'The rule that jumps out at me is "open brackets must be closed in the correct order" - the most recently opened bracket has to be the next one closed. That last-in-first-out pattern is the textbook signature of a stack. A naive approach I might first try is to repeatedly scan the string removing adjacent matching pairs like "()" or "[]" until nothing changes, and then check if the string is empty. That actually works, but each removal can cost a full pass and I might need many passes, so it is slow. The clean realization is that I do not need to keep collapsing the string - I can process it left to right exactly once. I push each opening bracket onto a stack, and whenever I hit a closing bracket I check that the top of the stack is its matching opener and pop it. If the stack is empty when I see a closer, or the top does not match, it is invalid immediately. At the very end the stack must be empty, otherwise some opener was never closed. One pass, O(1) checks each step.',
    walkthrough:
      'Brute force (repeated pair removal): while the string still contains any of the adjacent matching pairs "()", "[]", or "{}", replace those pairs with empty string and repeat. If we eventually reduce the string to empty it was valid; if a pass makes no change and the string is non-empty, it is invalid. Each replacement pass is O(n) and we may need O(n) passes.\n\nOptimal (single pass with a stack): keep a stack and a map closing_to_opening from each closing bracket to its matching opening bracket. For each character: if it is a closing bracket, it is valid only if the stack is non-empty and the top equals the matching opener, in which case we pop; otherwise return false. If it is an opening bracket, push it. After processing all characters, return true only if the stack is empty (no unclosed openers remain).',
    complexityAnalysis:
      'Brute force: Time O(n^2) because each removal pass scans O(n) and up to O(n) passes may be needed; Space O(n) for the working copy of the string.\n\nOptimal: Time O(n) since we scan the string once and each push/pop and lookup is O(1); Space O(n) for the stack in the worst case (a string of all opening brackets).',
    solutions: {
      python: `class Solution:
    def isValid(self, s: str) -> bool:
        # Brute force: repeatedly delete adjacent matching pairs.
        previous = None
        while previous != s:
            previous = s
            s = s.replace('()', '').replace('[]', '').replace('{}', '')
        return s == ''


class SolutionOptimal:
    def isValid(self, s: str) -> bool:
        # Optimal: single pass using a stack of open brackets.
        closing_to_opening = {')': '(', ']': '[', '}': '{'}
        stack = []

        for ch in s:
            if ch in closing_to_opening:
                # closing bracket must match the most recent opener
                if not stack or stack[-1] != closing_to_opening[ch]:
                    return False
                stack.pop()
            else:
                stack.append(ch)

        return len(stack) == 0
`,
      java: `class Solution {
    // Brute force: repeatedly delete adjacent matching pairs.
    public boolean isValid(String s) {
        String previous = null;
        while (!s.equals(previous)) {
            previous = s;
            s = s.replace("()", "").replace("[]", "").replace("{}", "");
        }
        return s.isEmpty();
    }
}

class SolutionOptimal {
    // Optimal: single pass using a stack of open brackets.
    public boolean isValid(String s) {
        Map<Character, Character> closingToOpening = new HashMap<>();
        closingToOpening.put(')', '(');
        closingToOpening.put(']', '[');
        closingToOpening.put('}', '{');

        Deque<Character> stack = new ArrayDeque<>();
        for (char ch : s.toCharArray()) {
            if (closingToOpening.containsKey(ch)) {
                if (stack.isEmpty() || stack.peek() != closingToOpening.get(ch)) {
                    return false;
                }
                stack.pop();
            } else {
                stack.push(ch);
            }
        }

        return stack.isEmpty();
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: repeatedly delete adjacent matching pairs.
    bool isValid(string s) {
        string previous;
        while (s != previous) {
            previous = s;
            s = removePairs(s);
        }
        return s.empty();
    }

private:
    string removePairs(const string& s) {
        string result;
        for (char ch : s) {
            if (!result.empty()
                && ((result.back() == '(' && ch == ')')
                 || (result.back() == '[' && ch == ']')
                 || (result.back() == '{' && ch == '}'))) {
                result.pop_back();
            } else {
                result.push_back(ch);
            }
        }
        return result;
    }
};

class SolutionOptimal {
public:
    // Optimal: single pass using a stack of open brackets.
    bool isValid(string s) {
        unordered_map<char, char> closingToOpening = {
            {')', '('}, {']', '['}, {'}', '{'}
        };
        vector<char> stack;

        for (char ch : s) {
            if (closingToOpening.count(ch)) {
                if (stack.empty() || stack.back() != closingToOpening[ch]) {
                    return false;
                }
                stack.pop_back();
            } else {
                stack.push_back(ch);
            }
        }

        return stack.empty();
    }
};
`,
    },
  },
  {
    problemNumber: 347,
    title: 'Top K Frequent Elements',
    slug: 'top-k-frequent-elements',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/top-k-frequent-elements',
    topics: ['Array', 'Hash Table', 'Divide and Conquer', 'Sorting', 'Heap (Priority Queue)', 'Bucket Sort', 'Counting', 'Quickselect'],
    companies: ['Tesla'],
    frequency: 82.2,
    acceptanceRate: 0.6457,
    problemStatement:
      'Given an integer array nums and an integer k, return the k most frequent elements. You may return the answer in any order.\n\nExample 1:\nInput: nums = [1,1,1,2,2,3], k = 2\nOutput: [1,2]\n\nExample 2:\nInput: nums = [1], k = 1\nOutput: [1]\n\nConstraints:\n1 <= nums.length <= 10^5\n-10^4 <= nums[i] <= 10^4\nk is in the range [1, the number of unique elements in the array].\nIt is guaranteed that the answer is unique.\n\nFollow up: Your algorithm\'s time complexity must be better than O(n log n), where n is the array\'s size.',
    hints: [
      'First count how many times each element appears using a hash map.',
      'You only need the k highest counts, not a full sort of all counts.',
      'A frequency cannot exceed n, so you can bucket elements by their frequency (index = count) and read buckets from high to low - this avoids any sorting.',
    ],
    intuition:
      'The first half is obvious: I need the frequency of each number, which a hash map gives me in one pass. The interesting part is extracting the top k. My naive instinct is to sort all the (number, count) pairs by count descending and take the first k. That is simple and correct but it is O(n log n) on the number of unique elements, and the follow-up explicitly asks me to beat that. The key realization is that frequencies are bounded: a number can appear at most n times, so there are only n possible frequency values. That lets me use bucket sort - I make an array of buckets indexed by frequency, and drop each number into the bucket matching its count. Then I just walk the buckets from the highest frequency down, collecting numbers until I have k of them. No comparison sort needed, and the whole thing is linear. A heap of size k is the other classic answer and is O(n log k), also better than full sorting, but bucket sort gives the cleanest O(n).',
    walkthrough:
      'Brute force (count then full sort): build a frequency map counts with one pass over nums. Convert it to a list of (number, frequency) pairs, sort that list by frequency in descending order, and take the first k numbers. The sort dominates at O(u log u) where u is the number of unique elements.\n\nOptimal (bucket sort by frequency): build the same counts map. Create a list buckets of length n + 1 where buckets[f] is a list of all numbers whose frequency is exactly f. Iterate the map and append each number to buckets[its count]. Then walk frequencies from n down to 1, appending the numbers in each non-empty bucket to a result list, stopping once result has k elements. Because frequency is at most n, indexing into buckets replaces sorting and the whole pass is linear.',
    complexityAnalysis:
      'Brute force: Time O(n + u log u) - O(n) to count and O(u log u) to sort the u unique elements by frequency; Space O(u) for the map and the pair list.\n\nOptimal (bucket sort): Time O(n) - one pass to count, one pass to fill n+1 buckets, and one pass over buckets to collect k results, all linear; Space O(n) for the frequency map and the bucket array of size n+1.',
    solutions: {
      python: `class Solution:
    def topKFrequent(self, nums, k):
        # Brute force: count frequencies, then sort all unique values by count.
        counts = {}
        for num in nums:
            counts[num] = counts.get(num, 0) + 1

        pairs = list(counts.items())
        pairs.sort(key=lambda pair: pair[1], reverse=True)
        return [number for number, _ in pairs[:k]]


class SolutionOptimal:
    def topKFrequent(self, nums, k):
        # Optimal: bucket sort by frequency (frequency is at most len(nums)).
        counts = {}
        for num in nums:
            counts[num] = counts.get(num, 0) + 1

        n = len(nums)
        buckets = [[] for _ in range(n + 1)]
        for number, frequency in counts.items():
            buckets[frequency].append(number)

        result = []
        for frequency in range(n, 0, -1):
            for number in buckets[frequency]:
                result.append(number)
                if len(result) == k:
                    return result
        return result
`,
      java: `class Solution {
    // Brute force: count frequencies, then sort unique values by count.
    public int[] topKFrequent(int[] nums, int k) {
        Map<Integer, Integer> counts = new HashMap<>();
        for (int num : nums) {
            counts.put(num, counts.getOrDefault(num, 0) + 1);
        }

        List<Integer> unique = new ArrayList<>(counts.keySet());
        unique.sort((a, b) -> counts.get(b) - counts.get(a));

        int[] result = new int[k];
        for (int i = 0; i < k; i++) {
            result[i] = unique.get(i);
        }
        return result;
    }
}

class SolutionOptimal {
    // Optimal: bucket sort by frequency (frequency is at most nums.length).
    public int[] topKFrequent(int[] nums, int k) {
        Map<Integer, Integer> counts = new HashMap<>();
        for (int num : nums) {
            counts.put(num, counts.getOrDefault(num, 0) + 1);
        }

        int n = nums.length;
        List<Integer>[] buckets = new List[n + 1];
        for (int i = 0; i <= n; i++) {
            buckets[i] = new ArrayList<>();
        }
        for (Map.Entry<Integer, Integer> entry : counts.entrySet()) {
            buckets[entry.getValue()].add(entry.getKey());
        }

        int[] result = new int[k];
        int filled = 0;
        for (int frequency = n; frequency >= 1 && filled < k; frequency--) {
            for (int number : buckets[frequency]) {
                result[filled++] = number;
                if (filled == k) {
                    break;
                }
            }
        }
        return result;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: count frequencies, then sort unique values by count.
    vector<int> topKFrequent(vector<int>& nums, int k) {
        unordered_map<int, int> counts;
        for (int num : nums) {
            counts[num]++;
        }

        vector<pair<int, int>> pairs(counts.begin(), counts.end());
        sort(pairs.begin(), pairs.end(),
             [](const pair<int, int>& a, const pair<int, int>& b) {
                 return a.second > b.second;
             });

        vector<int> result;
        for (int i = 0; i < k; i++) {
            result.push_back(pairs[i].first);
        }
        return result;
    }
};

class SolutionOptimal {
public:
    // Optimal: bucket sort by frequency (frequency is at most nums.size()).
    vector<int> topKFrequent(vector<int>& nums, int k) {
        unordered_map<int, int> counts;
        for (int num : nums) {
            counts[num]++;
        }

        int n = nums.size();
        vector<vector<int>> buckets(n + 1);
        for (auto& entry : counts) {
            buckets[entry.second].push_back(entry.first);
        }

        vector<int> result;
        for (int frequency = n; frequency >= 1 && (int)result.size() < k; frequency--) {
            for (int number : buckets[frequency]) {
                result.push_back(number);
                if ((int)result.size() == k) {
                    break;
                }
            }
        }
        return result;
    }
};
`,
    },
  },
  {
    problemNumber: 11,
    title: 'Container With Most Water',
    slug: 'container-with-most-water',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/container-with-most-water',
    topics: ['Array', 'Two Pointers', 'Greedy'],
    companies: ['Tesla'],
    frequency: 77.5,
    acceptanceRate: 0.5778,
    problemStatement:
      'You are given an integer array height of length n. There are n vertical lines drawn such that the two endpoints of the ith line are (i, 0) and (i, height[i]).\n\nFind two lines that together with the x-axis form a container, such that the container contains the most water.\n\nReturn the maximum amount of water a container can store.\n\nNotice that you may not slant the container.\n\nExample 1:\nInput: height = [1,8,6,2,5,4,8,3,7]\nOutput: 49\nExplanation: The vertical lines are drawn for the array [1,8,6,2,5,4,8,3,7]. The max area of water the container can contain is 49 (between the lines at index 1 and index 8).\n\nExample 2:\nInput: height = [1,1]\nOutput: 1\n\nConstraints:\nn == height.length\n2 <= n <= 10^5\n0 <= height[i] <= 10^4',
    hints: [
      'The water a pair of lines holds is the shorter of the two heights times the horizontal distance between them.',
      'Start with the widest possible container (the two ends) and think about how to shrink the width while possibly improving the area.',
      'Moving the pointer at the taller line can never help, since the area is capped by the shorter line; move the shorter line inward instead.',
    ],
    intuition:
      'The area between two lines is limited by the shorter line, multiplied by how far apart they are: min(height[left], height[right]) * (right - left). My first instinct is just to try every pair of lines and take the max - that is a clean double loop, definitely correct, but O(n^2). To do better I think about where the best container could be. If I start with the two ends, I have the maximum possible width. The only way a narrower container beats it is by being taller. Here is the key realization: the area is bounded by the shorter of the two lines, so if I move the pointer at the taller line inward, the width shrinks and the height is still capped by that same shorter line - it can never improve. So the only move that has any chance of helping is moving the shorter line inward, hoping to find a taller line that more than compensates for the lost width. That gives me a two-pointer sweep from both ends inward, always advancing whichever side is shorter, and it finds the optimum in one linear pass.',
    walkthrough:
      'Brute force (all pairs): use two nested loops over indices left and right, compute the area as min(height[left], height[right]) * (right - left) for each pair, and track the maximum. Straightforward but quadratic.\n\nOptimal (two pointers): set left to 0 and right to the last index. Repeatedly compute the current area with the formula above and update best_area. Then move the pointer that points at the shorter line inward: if height[left] < height[right], increment left, otherwise decrement right. Stop when left meets right. The reasoning is that the shorter line caps the area, so advancing the taller side can only reduce width without raising the cap - we discard it and only explore moves that might raise the limiting height.',
    complexityAnalysis:
      'Brute force: Time O(n^2) for the two nested loops over all pairs; Space O(1) since we only track the best area.\n\nOptimal: Time O(n) because left and right move toward each other and together traverse the array once; Space O(1) for the two pointers and the running maximum.',
    solutions: {
      python: `class Solution:
    def maxArea(self, height):
        # Brute force: try every pair of lines.
        n = len(height)
        best_area = 0
        for left in range(n):
            for right in range(left + 1, n):
                shorter = min(height[left], height[right])
                width = right - left
                best_area = max(best_area, shorter * width)
        return best_area


class SolutionOptimal:
    def maxArea(self, height):
        # Optimal: two pointers, always move the shorter side inward.
        left = 0
        right = len(height) - 1
        best_area = 0

        while left < right:
            shorter = min(height[left], height[right])
            width = right - left
            best_area = max(best_area, shorter * width)
            if height[left] < height[right]:
                left += 1
            else:
                right -= 1

        return best_area
`,
      java: `class Solution {
    // Brute force: try every pair of lines.
    public int maxArea(int[] height) {
        int n = height.length;
        int bestArea = 0;
        for (int left = 0; left < n; left++) {
            for (int right = left + 1; right < n; right++) {
                int shorter = Math.min(height[left], height[right]);
                int width = right - left;
                bestArea = Math.max(bestArea, shorter * width);
            }
        }
        return bestArea;
    }
}

class SolutionOptimal {
    // Optimal: two pointers, always move the shorter side inward.
    public int maxArea(int[] height) {
        int left = 0;
        int right = height.length - 1;
        int bestArea = 0;

        while (left < right) {
            int shorter = Math.min(height[left], height[right]);
            int width = right - left;
            bestArea = Math.max(bestArea, shorter * width);
            if (height[left] < height[right]) {
                left++;
            } else {
                right--;
            }
        }

        return bestArea;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: try every pair of lines.
    int maxArea(vector<int>& height) {
        int n = height.size();
        int bestArea = 0;
        for (int left = 0; left < n; left++) {
            for (int right = left + 1; right < n; right++) {
                int shorter = min(height[left], height[right]);
                int width = right - left;
                bestArea = max(bestArea, shorter * width);
            }
        }
        return bestArea;
    }
};

class SolutionOptimal {
public:
    // Optimal: two pointers, always move the shorter side inward.
    int maxArea(vector<int>& height) {
        int left = 0;
        int right = height.size() - 1;
        int bestArea = 0;

        while (left < right) {
            int shorter = min(height[left], height[right]);
            int width = right - left;
            bestArea = max(bestArea, shorter * width);
            if (height[left] < height[right]) {
                left++;
            } else {
                right--;
            }
        }

        return bestArea;
    }
};
`,
    },
  },
  {
    problemNumber: 146,
    title: 'LRU Cache',
    slug: 'lru-cache',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/lru-cache',
    topics: ['Hash Table', 'Linked List', 'Design', 'Doubly-Linked List'],
    companies: ['Tesla'],
    frequency: 77.5,
    acceptanceRate: 0.4521,
    problemStatement:
      'Design a data structure that follows the constraints of a Least Recently Used (LRU) cache.\n\nImplement the LRUCache class:\n- LRUCache(int capacity) Initialize the LRU cache with positive size capacity.\n- int get(int key) Return the value of the key if the key exists, otherwise return -1.\n- void put(int key, int value) Update the value of the key if the key exists. Otherwise, add the key-value pair to the cache. If the number of keys exceeds the capacity from this operation, evict the least recently used key.\n\nThe functions get and put must each run in O(1) average time complexity.\n\nExample 1:\nInput\n["LRUCache", "put", "put", "get", "put", "get", "put", "get", "get", "get"]\n[[2], [1, 1], [2, 2], [1], [3, 3], [2], [4, 4], [1], [3], [4]]\nOutput\n[null, null, null, 1, null, -1, null, -1, 3, 4]\n\nConstraints:\n1 <= capacity <= 3000\n0 <= key <= 10^4\n0 <= value <= 10^5\nAt most 2 * 10^5 calls will be made to get and put.',
    hints: [
      'You need O(1) lookup by key (a hash map) and O(1) ability to know and update which item is least vs most recently used (an ordering structure).',
      'A doubly linked list lets you move a node to the front or remove the tail node in O(1), if you have a pointer to it.',
      'Store key -> node in the hash map. On access, splice the node out and reinsert it at the most-recent end; evict from the least-recent end when over capacity.',
    ],
    intuition:
      'I need two things at once: fast lookup by key, and a fast way to track recency so I can evict the least recently used item. A hash map alone nails the lookup but tells me nothing about ordering. My first naive instinct is to keep an ordered list of keys alongside the map: on every access I move the key to the end of the list, and when full I evict from the front. The problem is that finding and removing a key in the middle of a plain list (or array) is O(n), which violates the required O(1). The key realization is that a doubly linked list lets me unlink any node in O(1) as long as I have a direct pointer to it - and a hash map can give me exactly that pointer, mapping key to its node. So I combine them: the hash map maps key to node, and the doubly linked list orders nodes from least recently used (near the head) to most recently used (near the tail). On get or put, I unlink the node and re-attach it at the most-recent end; on overflow I drop the node at the least-recent end and remove its key from the map. Every operation touches a constant number of pointers.',
    walkthrough:
      'Brute force (hash map + ordered key list with O(n) recency updates): store key -> value in a map and keep a separate list recency of keys ordered from least to most recently used. On get, if present, remove the key from recency (an O(n) search-and-remove) and append it to the end, then return the value. On put, update or insert into the map; refresh the key position in recency the same way; if size exceeds capacity, pop the first key in recency and delete it from the map. Correct, but the list operations are O(n).\n\nOptimal (hash map + doubly linked list): use a doubly linked list with sentinel head and tail nodes; the node right after head is least recently used, the node right before tail is most recently used. The map maps key -> node. A node stores key and value. On get, if the key is absent return -1; otherwise unlink the node and re-insert it just before tail (most recent), then return its value. On put, if the key exists, update its value and move it to most-recent; otherwise create a node, insert before tail, and add to the map; if size exceeds capacity, remove the node right after head, delete its key from the map. All operations are O(1).',
    complexityAnalysis:
      'Brute force: get and put are O(n) because keeping the recency list ordered requires searching for and removing a key inside a list; Space O(capacity) for the map and the recency list.\n\nOptimal: get and put are O(1) - the hash map gives O(1) node lookup and the doubly linked list supports O(1) unlink and insert at either end; Space O(capacity) for the map plus the linked list nodes.',
    solutions: {
      python: `class Solution:
    # Brute force: map for values + a list tracking recency order (O(n) updates).
    def __init__(self, capacity: int):
        self.capacity = capacity
        self.values = {}
        self.recency = []  # least recent at front, most recent at back

    def get(self, key: int) -> int:
        if key not in self.values:
            return -1
        self.recency.remove(key)   # O(n)
        self.recency.append(key)
        return self.values[key]

    def put(self, key: int, value: int) -> None:
        if key in self.values:
            self.values[key] = value
            self.recency.remove(key)  # O(n)
            self.recency.append(key)
            return
        if len(self.values) >= self.capacity:
            oldest = self.recency.pop(0)
            del self.values[oldest]
        self.values[key] = value
        self.recency.append(key)


class Node:
    def __init__(self, key=0, value=0):
        self.key = key
        self.value = value
        self.prev = None
        self.next = None


class SolutionOptimal:
    # Optimal: hash map (key -> node) + doubly linked list for O(1) recency.
    def __init__(self, capacity: int):
        self.capacity = capacity
        self.map = {}
        self.head = Node()  # sentinel; head.next is least recently used
        self.tail = Node()  # sentinel; tail.prev is most recently used
        self.head.next = self.tail
        self.tail.prev = self.head

    def _remove(self, node):
        node.prev.next = node.next
        node.next.prev = node.prev

    def _insert_most_recent(self, node):
        node.prev = self.tail.prev
        node.next = self.tail
        self.tail.prev.next = node
        self.tail.prev = node

    def get(self, key: int) -> int:
        if key not in self.map:
            return -1
        node = self.map[key]
        self._remove(node)
        self._insert_most_recent(node)
        return node.value

    def put(self, key: int, value: int) -> None:
        if key in self.map:
            node = self.map[key]
            node.value = value
            self._remove(node)
            self._insert_most_recent(node)
            return
        if len(self.map) >= self.capacity:
            lru = self.head.next
            self._remove(lru)
            del self.map[lru.key]
        node = Node(key, value)
        self.map[key] = node
        self._insert_most_recent(node)
`,
      java: `class Solution {
    // Brute force: map for values + a list tracking recency order (O(n) updates).
    private int capacity;
    private Map<Integer, Integer> values;
    private List<Integer> recency; // least recent at front

    public Solution(int capacity) {
        this.capacity = capacity;
        this.values = new HashMap<>();
        this.recency = new ArrayList<>();
    }

    public int get(int key) {
        if (!values.containsKey(key)) {
            return -1;
        }
        recency.remove(Integer.valueOf(key)); // O(n)
        recency.add(key);
        return values.get(key);
    }

    public void put(int key, int value) {
        if (values.containsKey(key)) {
            values.put(key, value);
            recency.remove(Integer.valueOf(key)); // O(n)
            recency.add(key);
            return;
        }
        if (values.size() >= capacity) {
            int oldest = recency.remove(0);
            values.remove(oldest);
        }
        values.put(key, value);
        recency.add(key);
    }
}

class SolutionOptimal {
    // Optimal: hash map (key -> node) + doubly linked list for O(1) recency.
    private class Node {
        int key, value;
        Node prev, next;
        Node(int key, int value) { this.key = key; this.value = value; }
    }

    private int capacity;
    private Map<Integer, Node> map;
    private Node head, tail; // sentinels

    public SolutionOptimal(int capacity) {
        this.capacity = capacity;
        this.map = new HashMap<>();
        this.head = new Node(0, 0);
        this.tail = new Node(0, 0);
        head.next = tail;
        tail.prev = head;
    }

    private void remove(Node node) {
        node.prev.next = node.next;
        node.next.prev = node.prev;
    }

    private void insertMostRecent(Node node) {
        node.prev = tail.prev;
        node.next = tail;
        tail.prev.next = node;
        tail.prev = node;
    }

    public int get(int key) {
        if (!map.containsKey(key)) {
            return -1;
        }
        Node node = map.get(key);
        remove(node);
        insertMostRecent(node);
        return node.value;
    }

    public void put(int key, int value) {
        if (map.containsKey(key)) {
            Node node = map.get(key);
            node.value = value;
            remove(node);
            insertMostRecent(node);
            return;
        }
        if (map.size() >= capacity) {
            Node lru = head.next;
            remove(lru);
            map.remove(lru.key);
        }
        Node node = new Node(key, value);
        map.put(key, node);
        insertMostRecent(node);
    }
}
`,
      cpp: `class Solution {
    // Brute force: map for values + a list tracking recency order (O(n) updates).
private:
    int capacity;
    unordered_map<int, int> values;
    vector<int> recency; // least recent at front

public:
    Solution(int capacity) : capacity(capacity) {}

    int get(int key) {
        if (values.find(key) == values.end()) {
            return -1;
        }
        recency.erase(find(recency.begin(), recency.end(), key)); // O(n)
        recency.push_back(key);
        return values[key];
    }

    void put(int key, int value) {
        if (values.find(key) != values.end()) {
            values[key] = value;
            recency.erase(find(recency.begin(), recency.end(), key)); // O(n)
            recency.push_back(key);
            return;
        }
        if ((int)values.size() >= capacity) {
            int oldest = recency.front();
            recency.erase(recency.begin());
            values.erase(oldest);
        }
        values[key] = value;
        recency.push_back(key);
    }
};

class SolutionOptimal {
    // Optimal: hash map (key -> node) + doubly linked list for O(1) recency.
private:
    struct Node {
        int key, value;
        Node* prev;
        Node* next;
        Node(int k, int v) : key(k), value(v), prev(nullptr), next(nullptr) {}
    };

    int capacity;
    unordered_map<int, Node*> map;
    Node* head; // sentinel
    Node* tail; // sentinel

    void remove(Node* node) {
        node->prev->next = node->next;
        node->next->prev = node->prev;
    }

    void insertMostRecent(Node* node) {
        node->prev = tail->prev;
        node->next = tail;
        tail->prev->next = node;
        tail->prev = node;
    }

public:
    SolutionOptimal(int capacity) : capacity(capacity) {
        head = new Node(0, 0);
        tail = new Node(0, 0);
        head->next = tail;
        tail->prev = head;
    }

    int get(int key) {
        if (map.find(key) == map.end()) {
            return -1;
        }
        Node* node = map[key];
        remove(node);
        insertMostRecent(node);
        return node->value;
    }

    void put(int key, int value) {
        if (map.find(key) != map.end()) {
            Node* node = map[key];
            node->value = value;
            remove(node);
            insertMostRecent(node);
            return;
        }
        if ((int)map.size() >= capacity) {
            Node* lru = head->next;
            remove(lru);
            map.erase(lru->key);
            delete lru;
        }
        Node* node = new Node(key, value);
        map[key] = node;
        insertMostRecent(node);
    }
};
`,
    },
  },
  {
    problemNumber: 121,
    title: 'Best Time to Buy and Sell Stock',
    slug: 'best-time-to-buy-and-sell-stock',
    difficulty: 'EASY',
    link: 'https://leetcode.com/problems/best-time-to-buy-and-sell-stock',
    topics: ['Array', 'Dynamic Programming'],
    companies: ['Tesla'],
    frequency: 77.5,
    acceptanceRate: 0.5526,
    problemStatement:
      'You are given an array prices where prices[i] is the price of a given stock on the ith day.\n\nYou want to maximize your profit by choosing a single day to buy one stock and choosing a different day in the future to sell that stock.\n\nReturn the maximum profit you can achieve from this transaction. If you cannot achieve any profit, return 0.\n\nExample 1:\nInput: prices = [7,1,5,3,6,4]\nOutput: 5\nExplanation: Buy on day 2 (price = 1) and sell on day 5 (price = 6), profit = 6-1 = 5. Note that buying on day 2 and selling on day 1 is not allowed because you must buy before you sell.\n\nExample 2:\nInput: prices = [7,6,4,3,1]\nOutput: 0\nExplanation: In this case, no transactions are done and the max profit = 0.\n\nConstraints:\n1 <= prices.length <= 10^5\n0 <= prices[i] <= 10^4',
    hints: [
      'To sell on a given day for maximum profit, you want to have bought on the cheapest day that came before it.',
      'As you scan left to right, keep track of the lowest price seen so far.',
      'At each day, the best profit selling that day is today\'s price minus the minimum price seen so far; track the overall maximum.',
    ],
    intuition:
      'The constraint that I must buy before I sell is the whole game here. My first instinct is brute force: try every pair of days (buy_day, sell_day) with sell after buy, compute the profit, and keep the max. That is O(n^2) and obviously correct. But when I think about what I actually need to decide the best sell on a given day, I realize it only depends on one thing: the cheapest price that appeared on any earlier day. If I am standing on day i thinking about selling, my best possible profit today is today\'s price minus the minimum price I have seen so far. The key realization is that I can maintain that running minimum in a single left-to-right pass. I keep min_price_so_far updated as I go, and at each day I compute today\'s price minus that minimum and update best_profit. I never have to look backward explicitly because the running minimum already summarizes the entire past. One pass, constant extra space.',
    walkthrough:
      'Brute force (all pairs): use two nested loops; the outer picks buy_day, the inner picks sell_day after it, and compute prices[sell_day] - prices[buy_day], updating best_profit whenever it is larger. Quadratic in the number of days.\n\nOptimal (track running minimum): initialize min_price_so_far to the first price and best_profit to 0. Walk through prices once. At each price, the profit if we sold today is price - min_price_so_far; update best_profit if that is larger. Then update min_price_so_far to the smaller of itself and the current price so future days can buy at the cheapest point seen so far. Return best_profit.',
    complexityAnalysis:
      'Brute force: Time O(n^2) from the nested loops over all buy/sell day pairs; Space O(1) for the running best.\n\nOptimal: Time O(n) for the single pass; Space O(1) because we only keep the running minimum price and the best profit.',
    solutions: {
      python: `class Solution:
    def maxProfit(self, prices):
        # Brute force: try every (buy day, later sell day) pair.
        best_profit = 0
        n = len(prices)
        for buy_day in range(n):
            for sell_day in range(buy_day + 1, n):
                profit = prices[sell_day] - prices[buy_day]
                best_profit = max(best_profit, profit)
        return best_profit


class SolutionOptimal:
    def maxProfit(self, prices):
        # Optimal: track the cheapest price seen so far in one pass.
        min_price_so_far = prices[0]
        best_profit = 0

        for price in prices:
            best_profit = max(best_profit, price - min_price_so_far)
            min_price_so_far = min(min_price_so_far, price)

        return best_profit
`,
      java: `class Solution {
    // Brute force: try every (buy day, later sell day) pair.
    public int maxProfit(int[] prices) {
        int bestProfit = 0;
        int n = prices.length;
        for (int buyDay = 0; buyDay < n; buyDay++) {
            for (int sellDay = buyDay + 1; sellDay < n; sellDay++) {
                int profit = prices[sellDay] - prices[buyDay];
                bestProfit = Math.max(bestProfit, profit);
            }
        }
        return bestProfit;
    }
}

class SolutionOptimal {
    // Optimal: track the cheapest price seen so far in one pass.
    public int maxProfit(int[] prices) {
        int minPriceSoFar = prices[0];
        int bestProfit = 0;

        for (int price : prices) {
            bestProfit = Math.max(bestProfit, price - minPriceSoFar);
            minPriceSoFar = Math.min(minPriceSoFar, price);
        }

        return bestProfit;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: try every (buy day, later sell day) pair.
    int maxProfit(vector<int>& prices) {
        int bestProfit = 0;
        int n = prices.size();
        for (int buyDay = 0; buyDay < n; buyDay++) {
            for (int sellDay = buyDay + 1; sellDay < n; sellDay++) {
                int profit = prices[sellDay] - prices[buyDay];
                bestProfit = max(bestProfit, profit);
            }
        }
        return bestProfit;
    }
};

class SolutionOptimal {
public:
    // Optimal: track the cheapest price seen so far in one pass.
    int maxProfit(vector<int>& prices) {
        int minPriceSoFar = prices[0];
        int bestProfit = 0;

        for (int price : prices) {
            bestProfit = max(bestProfit, price - minPriceSoFar);
            minPriceSoFar = min(minPriceSoFar, price);
        }

        return bestProfit;
    }
};
`,
    },
  },
  {
    problemNumber: 25,
    title: 'Reverse Nodes in k-Group',
    slug: 'reverse-nodes-in-k-group',
    difficulty: 'HARD',
    link: 'https://leetcode.com/problems/reverse-nodes-in-k-group',
    topics: ['Linked List', 'Recursion'],
    companies: ['Tesla'],
    frequency: 71.8,
    acceptanceRate: 0.6304,
    problemStatement:
      'Given the head of a linked list, reverse the nodes of the list k at a time, and return the modified list.\n\nk is a positive integer and is less than or equal to the length of the linked list. If the number of nodes is not a multiple of k then left-out nodes, in the end, should remain as it is.\n\nYou may not alter the values in the list\'s nodes, only nodes themselves may be changed.\n\nExample 1:\nInput: head = [1,2,3,4,5], k = 2\nOutput: [2,1,4,3,5]\n\nExample 2:\nInput: head = [1,2,3,4,5], k = 3\nOutput: [3,2,1,4,5]\n\nConstraints:\nThe number of nodes in the list is n.\n1 <= k <= n <= 5000\n0 <= Node.val <= 1000\n\nFollow-up: Can you solve the problem in O(1) extra memory space?',
    hints: [
      'First check whether there are at least k nodes remaining; if not, leave them as they are.',
      'Reverse exactly k nodes, then recurse (or iterate) on the rest and connect the reversed group to the result of the remainder.',
      'For O(1) space, do it iteratively: reverse each group in place and stitch the tail of one reversed group to the head of the next.',
    ],
    intuition:
      'A linked list reversal is something I know how to do, but the twist is doing it in fixed-size chunks and leaving a final short chunk untouched. My first instinct is the value-copying shortcut - dump everything into an array, reverse k-sized blocks, and rebuild - but the problem explicitly forbids changing values, so I have to actually relink nodes. The cleanest mental model for me is recursion: I look at the front of the list, check that there are at least k nodes available; if not, I leave this tail alone and return it as-is. If there are k nodes, I reverse just those k pointers, which gives me a new head for this group and leaves the original first node as the group\'s tail. That tail\'s next should point to whatever the recursive call on the remaining list returns. The key realization is that each group\'s reversal is independent once I know it has k nodes, and the recursion naturally handles "connect this reversed block to the processed remainder." For O(1) space the same idea becomes an iterative loop that walks group by group, reversing in place and stitching the previous group\'s tail to the next group\'s new head.',
    walkthrough:
      'Brute force (recursion, O(n/k) stack space): write a recursive function. First walk k steps from head to confirm at least k nodes remain; if fewer, return head unchanged. Otherwise reverse the first k nodes using three pointers (previous, current, upcoming), which makes the kth node the new head and the original head the group tail. Recurse on the node after the group, and set the original head\'s next to that recursive result. Return the new head.\n\nOptimal (iterative, O(1) space): use a dummy node before head and a pointer group_prev marking the node just before the current group. Loop: find the kth node from group_prev; if it does not exist, stop. Record group_next as the node after the kth. Reverse the group in place by repointing pointers so the nodes between group_prev and group_next are reversed, then reconnect group_prev to the new group head and advance group_prev to the original first node of the group (now the tail). Continue until fewer than k nodes remain. Return dummy.next.',
    complexityAnalysis:
      'Brute force (recursive): Time O(n) since each node is visited a constant number of times across the reversals; Space O(n/k) for the recursion stack (one frame per group).\n\nOptimal (iterative): Time O(n) for the same reason - every node is part of exactly one in-place reversal; Space O(1) because the reversal uses a fixed number of pointers and no recursion.',
    solutions: {
      python: `# Definition for singly-linked list.
# class ListNode:
#     def __init__(self, val=0, next=None):
#         self.val = val
#         self.next = next


class Solution:
    def reverseKGroup(self, head, k):
        # Brute force: recursion (uses O(n/k) stack space).
        # Check there are at least k nodes remaining.
        node = head
        count = 0
        while node and count < k:
            node = node.next
            count += 1
        if count < k:
            return head  # fewer than k nodes left, leave as-is

        # Reverse the first k nodes.
        previous = None
        current = head
        for _ in range(k):
            upcoming = current.next
            current.next = previous
            previous = current
            current = upcoming

        # head is now the tail of this group; link it to the reversed remainder.
        head.next = self.reverseKGroup(current, k)
        return previous


class SolutionOptimal:
    def reverseKGroup(self, head, k):
        # Optimal: iterative, O(1) extra space.
        dummy = ListNode(0)
        dummy.next = head
        group_prev = dummy

        while True:
            # Find the kth node from group_prev.
            kth = group_prev
            for _ in range(k):
                kth = kth.next
                if not kth:
                    return dummy.next

            group_next = kth.next
            # Reverse the group between group_prev and group_next.
            previous = group_next
            current = group_prev.next
            while current != group_next:
                upcoming = current.next
                current.next = previous
                previous = current
                current = upcoming

            # Reconnect: group_prev.next was the group's first node (now tail).
            new_tail = group_prev.next
            group_prev.next = kth  # kth is the new head of the group
            group_prev = new_tail
`,
      java: `/**
 * Definition for singly-linked list.
 * class ListNode {
 *     int val;
 *     ListNode next;
 *     ListNode(int x) { val = x; }
 * }
 */
class Solution {
    // Brute force: recursion (uses O(n/k) stack space).
    public ListNode reverseKGroup(ListNode head, int k) {
        // Check there are at least k nodes remaining.
        ListNode node = head;
        int count = 0;
        while (node != null && count < k) {
            node = node.next;
            count++;
        }
        if (count < k) {
            return head; // fewer than k nodes, leave as-is
        }

        // Reverse the first k nodes.
        ListNode previous = null;
        ListNode current = head;
        for (int i = 0; i < k; i++) {
            ListNode upcoming = current.next;
            current.next = previous;
            previous = current;
            current = upcoming;
        }

        // head is now the tail of this group; link to reversed remainder.
        head.next = reverseKGroup(current, k);
        return previous;
    }
}

class SolutionOptimal {
    // Optimal: iterative, O(1) extra space.
    public ListNode reverseKGroup(ListNode head, int k) {
        ListNode dummy = new ListNode(0);
        dummy.next = head;
        ListNode groupPrev = dummy;

        while (true) {
            // Find the kth node from groupPrev.
            ListNode kth = groupPrev;
            for (int i = 0; i < k; i++) {
                kth = kth.next;
                if (kth == null) {
                    return dummy.next;
                }
            }

            ListNode groupNext = kth.next;
            // Reverse the group between groupPrev and groupNext.
            ListNode previous = groupNext;
            ListNode current = groupPrev.next;
            while (current != groupNext) {
                ListNode upcoming = current.next;
                current.next = previous;
                previous = current;
                current = upcoming;
            }

            ListNode newTail = groupPrev.next;
            groupPrev.next = kth; // kth is the new head of the group
            groupPrev = newTail;
        }
    }
}
`,
      cpp: `/**
 * Definition for singly-linked list.
 * struct ListNode {
 *     int val;
 *     ListNode *next;
 *     ListNode(int x) : val(x), next(nullptr) {}
 * };
 */
class Solution {
public:
    // Brute force: recursion (uses O(n/k) stack space).
    ListNode* reverseKGroup(ListNode* head, int k) {
        // Check there are at least k nodes remaining.
        ListNode* node = head;
        int count = 0;
        while (node != nullptr && count < k) {
            node = node->next;
            count++;
        }
        if (count < k) {
            return head; // fewer than k nodes, leave as-is
        }

        // Reverse the first k nodes.
        ListNode* previous = nullptr;
        ListNode* current = head;
        for (int i = 0; i < k; i++) {
            ListNode* upcoming = current->next;
            current->next = previous;
            previous = current;
            current = upcoming;
        }

        // head is now the tail of this group; link to reversed remainder.
        head->next = reverseKGroup(current, k);
        return previous;
    }
};

class SolutionOptimal {
public:
    // Optimal: iterative, O(1) extra space.
    ListNode* reverseKGroup(ListNode* head, int k) {
        ListNode dummy(0);
        dummy.next = head;
        ListNode* groupPrev = &dummy;

        while (true) {
            // Find the kth node from groupPrev.
            ListNode* kth = groupPrev;
            for (int i = 0; i < k; i++) {
                kth = kth->next;
                if (kth == nullptr) {
                    return dummy.next;
                }
            }

            ListNode* groupNext = kth->next;
            // Reverse the group between groupPrev and groupNext.
            ListNode* previous = groupNext;
            ListNode* current = groupPrev->next;
            while (current != groupNext) {
                ListNode* upcoming = current->next;
                current->next = previous;
                previous = current;
                current = upcoming;
            }

            ListNode* newTail = groupPrev->next;
            groupPrev->next = kth; // kth is the new head of the group
            groupPrev = newTail;
        }
    }
};
`,
    },
  },
  {
    problemNumber: 1189,
    title: 'Maximum Number of Balloons',
    slug: 'maximum-number-of-balloons',
    difficulty: 'EASY',
    link: 'https://leetcode.com/problems/maximum-number-of-balloons',
    topics: ['Hash Table', 'String', 'Counting'],
    companies: ['Tesla'],
    frequency: 71.8,
    acceptanceRate: 0.5974,
    problemStatement:
      'Given a string text, you want to use the characters of text to form as many instances of the word "balloon" as possible.\n\nYou can use each character in text at most once. Return the maximum number of instances that can be formed.\n\nExample 1:\nInput: text = "nlaebolko"\nOutput: 1\n\nExample 2:\nInput: text = "loonbalxballpoon"\nOutput: 2\n\nExample 3:\nInput: text = "leetcode"\nOutput: 0\n\nConstraints:\n1 <= text.length <= 10^4\ntext consists of lower case English letters only.',
    hints: [
      'Count how many of each letter you have available in text.',
      'The word "balloon" needs b:1, a:1, l:2, o:2, n:1. The doubled letters l and o are the constraint to watch.',
      'For each required letter, divide your available count by how many that letter is needed per word; the answer is the minimum over all letters.',
    ],
    intuition:
      'The word "balloon" is a fixed recipe of letters: one b, one a, two l, two o, one n. To build copies of it, each copy consumes that exact set, so the question is really "how many full recipes can I make given my ingredient counts?" My first instinct is to literally simulate it: count my letters, then repeatedly try to subtract one full "balloon" worth of letters and increment a counter until I run out of some letter. That works and is easy to reason about. But I notice it is doing the same division over and over - it is essentially asking, for each letter, how many copies that letter alone could support, and the bottleneck letter decides the total. The key realization is that the letters l and o are needed twice per word, so their effective supply is their count divided by 2. So I count each letter, and for b, a, n I use the raw count, while for l and o I use count // 2. The answer is simply the minimum of those five values, because the scarcest ingredient limits how many complete words I can spell.',
    walkthrough:
      'Brute force (repeated subtraction simulation): count the letters of text into a map available. Then loop: check whether available still has at least the letters of one "balloon" (b>=1, a>=1, l>=2, o>=2, n>=1); if so, subtract those and increment count; otherwise stop. Return count. Correct but it repeats the same feasibility check many times.\n\nOptimal (count and take the minimum): build the letter counts of text. The required letters are b, a, l, o, n with l and o needed twice. Compute candidate values: available[\'b\'], available[\'a\'], available[\'l\'] // 2, available[\'o\'] // 2, available[\'n\'] (using 0 for any missing letter). The answer is the minimum of these five, since the limiting letter caps the number of complete words.',
    complexityAnalysis:
      'Brute force: Time O(n + answer) - O(n) to count plus one subtraction round per word formed (the answer is at most n/7); Space O(1) since the count map holds at most 26 letters.\n\nOptimal: Time O(n) for the single counting pass plus O(1) to take the minimum over five fixed letters; Space O(1) for the fixed-size letter count map.',
    solutions: {
      python: `class Solution:
    def maxNumberOfBalloons(self, text: str) -> int:
        # Brute force: count letters, then repeatedly subtract one "balloon".
        available = {}
        for ch in text:
            available[ch] = available.get(ch, 0) + 1

        needed = {'b': 1, 'a': 1, 'l': 2, 'o': 2, 'n': 1}
        count = 0
        while all(available.get(ch, 0) >= amount for ch, amount in needed.items()):
            for ch, amount in needed.items():
                available[ch] -= amount
            count += 1
        return count


class SolutionOptimal:
    def maxNumberOfBalloons(self, text: str) -> int:
        # Optimal: count letters, the scarcest required letter limits the answer.
        available = {}
        for ch in text:
            available[ch] = available.get(ch, 0) + 1

        return min(
            available.get('b', 0),
            available.get('a', 0),
            available.get('l', 0) // 2,
            available.get('o', 0) // 2,
            available.get('n', 0),
        )
`,
      java: `class Solution {
    // Brute force: count letters, then repeatedly subtract one "balloon".
    public int maxNumberOfBalloons(String text) {
        int[] available = new int[26];
        for (char ch : text.toCharArray()) {
            available[ch - 'a']++;
        }

        int count = 0;
        while (available['b' - 'a'] >= 1 && available['a' - 'a'] >= 1
                && available['l' - 'a'] >= 2 && available['o' - 'a'] >= 2
                && available['n' - 'a'] >= 1) {
            available['b' - 'a'] -= 1;
            available['a' - 'a'] -= 1;
            available['l' - 'a'] -= 2;
            available['o' - 'a'] -= 2;
            available['n' - 'a'] -= 1;
            count++;
        }
        return count;
    }
}

class SolutionOptimal {
    // Optimal: count letters, the scarcest required letter limits the answer.
    public int maxNumberOfBalloons(String text) {
        int[] available = new int[26];
        for (char ch : text.toCharArray()) {
            available[ch - 'a']++;
        }

        int result = available['b' - 'a'];
        result = Math.min(result, available['a' - 'a']);
        result = Math.min(result, available['l' - 'a'] / 2);
        result = Math.min(result, available['o' - 'a'] / 2);
        result = Math.min(result, available['n' - 'a']);
        return result;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: count letters, then repeatedly subtract one "balloon".
    int maxNumberOfBalloons(string text) {
        vector<int> available(26, 0);
        for (char ch : text) {
            available[ch - 'a']++;
        }

        int count = 0;
        while (available['b' - 'a'] >= 1 && available['a' - 'a'] >= 1
                && available['l' - 'a'] >= 2 && available['o' - 'a'] >= 2
                && available['n' - 'a'] >= 1) {
            available['b' - 'a'] -= 1;
            available['a' - 'a'] -= 1;
            available['l' - 'a'] -= 2;
            available['o' - 'a'] -= 2;
            available['n' - 'a'] -= 1;
            count++;
        }
        return count;
    }
};

class SolutionOptimal {
public:
    // Optimal: count letters, the scarcest required letter limits the answer.
    int maxNumberOfBalloons(string text) {
        vector<int> available(26, 0);
        for (char ch : text) {
            available[ch - 'a']++;
        }

        int result = available['b' - 'a'];
        result = min(result, available['a' - 'a']);
        result = min(result, available['l' - 'a'] / 2);
        result = min(result, available['o' - 'a'] / 2);
        result = min(result, available['n' - 'a']);
        return result;
    }
};
`,
    },
  },
  {
    problemNumber: 283,
    title: 'Move Zeroes',
    slug: 'move-zeroes',
    difficulty: 'EASY',
    link: 'https://leetcode.com/problems/move-zeroes',
    topics: ['Array', 'Two Pointers'],
    companies: ['Tesla'],
    frequency: 71.8,
    acceptanceRate: 0.6280,
    problemStatement:
      'Given an integer array nums, move all 0\'s to the end of it while maintaining the relative order of the non-zero elements.\n\nNote that you must do this in-place without making a copy of the array.\n\nExample 1:\nInput: nums = [0,1,0,3,12]\nOutput: [1,3,12,0,0]\n\nExample 2:\nInput: nums = [0]\nOutput: [0]\n\nConstraints:\n1 <= nums.length <= 10^4\n-2^31 <= nums[i] <= 2^31 - 1\n\nFollow up: Could you minimize the total number of operations done?',
    hints: [
      'The non-zero elements should keep their relative order, packed at the front.',
      'Keep a pointer to the next slot where a non-zero element should go; as you scan, write each non-zero element there and advance it.',
      'After all non-zero elements are placed, fill the remaining slots with zeros (or swap as you go to keep it a single pass).',
    ],
    intuition:
      'The core observation is that "move zeroes to the end while keeping order" is the same as "pack all the non-zero elements toward the front in order, then everything left over must be zeros." My first naive instinct is to build a new array of all the non-zeros and pad it with zeros, then copy it back - but the problem says no copy and in-place. The key realization is that I can use a write pointer that marks the next position where a non-zero value belongs. I scan the array with a read index; every time I see a non-zero value, I place it at the write pointer and advance the write pointer. After the scan, all non-zeros are packed at the front in their original order, and the write pointer tells me exactly where the zeros should begin, so I just fill the rest with zeros. To make it a true single pass with minimal operations, I can instead swap the current non-zero element with the element at the write pointer as I go, which moves zeros toward the back naturally without a second loop.',
    walkthrough:
      'Brute force (extra array): create a new list, first append every non-zero element of nums in order, then append a zero for each zero that was in nums. Copy these values back into nums position by position. Simple, but it uses O(n) extra space, which the problem discourages.\n\nOptimal (two pointers, in place): keep write_index starting at 0. Scan read_index from left to right; whenever nums[read_index] is non-zero, swap nums[write_index] and nums[read_index] and increment write_index. Because write_index only lags behind read_index by the number of zeros seen, every non-zero element lands in order at the front and zeros bubble toward the back, all in one pass with O(1) extra space.',
    complexityAnalysis:
      'Brute force: Time O(n) for the two construction passes plus the copy back; Space O(n) for the temporary array.\n\nOptimal: Time O(n) for the single scan with constant-time swaps; Space O(1) because the rearrangement happens in place with just the two index pointers.',
    solutions: {
      python: `class Solution:
    def moveZeroes(self, nums) -> None:
        # Brute force: build a packed copy, then write it back.
        packed = [num for num in nums if num != 0]
        zero_count = len(nums) - len(packed)
        packed.extend([0] * zero_count)
        for i in range(len(nums)):
            nums[i] = packed[i]


class SolutionOptimal:
    def moveZeroes(self, nums) -> None:
        # Optimal: in-place two pointers, swap non-zeros to the front.
        write_index = 0
        for read_index in range(len(nums)):
            if nums[read_index] != 0:
                nums[write_index], nums[read_index] = nums[read_index], nums[write_index]
                write_index += 1
`,
      java: `class Solution {
    // Brute force: build a packed copy, then write it back.
    public void moveZeroes(int[] nums) {
        int[] packed = new int[nums.length];
        int index = 0;
        for (int num : nums) {
            if (num != 0) {
                packed[index++] = num;
            }
        }
        // remaining slots in packed are already 0 by default
        for (int i = 0; i < nums.length; i++) {
            nums[i] = packed[i];
        }
    }
}

class SolutionOptimal {
    // Optimal: in-place two pointers, swap non-zeros to the front.
    public void moveZeroes(int[] nums) {
        int writeIndex = 0;
        for (int readIndex = 0; readIndex < nums.length; readIndex++) {
            if (nums[readIndex] != 0) {
                int temp = nums[writeIndex];
                nums[writeIndex] = nums[readIndex];
                nums[readIndex] = temp;
                writeIndex++;
            }
        }
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: build a packed copy, then write it back.
    void moveZeroes(vector<int>& nums) {
        vector<int> packed(nums.size(), 0);
        int index = 0;
        for (int num : nums) {
            if (num != 0) {
                packed[index++] = num;
            }
        }
        for (int i = 0; i < (int)nums.size(); i++) {
            nums[i] = packed[i];
        }
    }
};

class SolutionOptimal {
public:
    // Optimal: in-place two pointers, swap non-zeros to the front.
    void moveZeroes(vector<int>& nums) {
        int writeIndex = 0;
        for (int readIndex = 0; readIndex < (int)nums.size(); readIndex++) {
            if (nums[readIndex] != 0) {
                swap(nums[writeIndex], nums[readIndex]);
                writeIndex++;
            }
        }
    }
};
`,
    },
  },
  {
    problemNumber: 560,
    title: 'Subarray Sum Equals K',
    slug: 'subarray-sum-equals-k',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/subarray-sum-equals-k',
    topics: ['Array', 'Hash Table', 'Prefix Sum'],
    companies: ['Tesla'],
    frequency: 71.8,
    acceptanceRate: 0.4548,
    problemStatement:
      'Given an array of integers nums and an integer k, return the total number of subarrays whose sum equals to k.\n\nA subarray is a contiguous non-empty sequence of elements within an array.\n\nExample 1:\nInput: nums = [1,1,1], k = 2\nOutput: 2\n\nExample 2:\nInput: nums = [1,2,3], k = 3\nOutput: 2\n\nConstraints:\n1 <= nums.length <= 2 * 10^4\n-1000 <= nums[i] <= 1000\n-10^7 <= k <= 10^7',
    hints: [
      'The sum of a subarray nums[i..j] equals prefix[j] - prefix[i-1], where prefix is the running sum.',
      'A subarray ending at index j sums to k exactly when some earlier prefix sum equals (current prefix sum - k).',
      'Use a hash map counting how many times each prefix sum has occurred so far, so you can look up matches in O(1).',
    ],
    intuition:
      'The brute force is obvious: consider every subarray, add up its elements, and count those equal to k. That is O(n^2) (or O(n^3) if I re-add each time). To speed it up, I think in terms of prefix sums - the running total from the start up to each index. The sum of the subarray from i to j is just prefix_sum_at_j minus prefix_sum_just_before_i. So a subarray ending at j has sum k exactly when there was an earlier prefix sum equal to current_prefix - k. The key realization is that I do not need to know where those earlier prefixes were, only how many of them there were, because each one marks a distinct valid starting point. So I maintain a hash map counting how many times each prefix sum value has occurred as I sweep left to right. At each index, I compute the current running sum, look up how many times current_sum - k has already appeared, and add that to my answer. Then I record the current sum in the map. This turns the quadratic search into a single linear pass.',
    walkthrough:
      'Brute force (all subarrays): for each start index i, accumulate a running sum over end indices j from i forward, and increment count whenever that running sum equals k. Using the running sum avoids re-adding from scratch, keeping it O(n^2).\n\nOptimal (prefix sums + hash map): maintain prefix_counts, a map from a prefix sum value to how many times it has occurred, initialized with {0: 1} to account for subarrays starting at index 0. Walk through nums maintaining current_sum. At each element, add current_sum - k\'s count in the map to the answer (each prior matching prefix marks a valid subarray ending here). Then increment prefix_counts[current_sum]. Return the accumulated count.',
    complexityAnalysis:
      'Brute force: Time O(n^2) because for each of n start indices we extend the subarray up to n times; Space O(1) aside from the counter.\n\nOptimal: Time O(n) for the single pass with O(1) average hash map lookups and updates; Space O(n) for the prefix-sum count map, which can hold up to n distinct prefix sums.',
    solutions: {
      python: `class Solution:
    def subarraySum(self, nums, k):
        # Brute force: for each start, extend and track the running sum.
        count = 0
        n = len(nums)
        for start in range(n):
            running_sum = 0
            for end in range(start, n):
                running_sum += nums[end]
                if running_sum == k:
                    count += 1
        return count


class SolutionOptimal:
    def subarraySum(self, nums, k):
        # Optimal: prefix sums; count how many earlier prefixes equal sum - k.
        prefix_counts = {0: 1}
        current_sum = 0
        count = 0

        for num in nums:
            current_sum += num
            count += prefix_counts.get(current_sum - k, 0)
            prefix_counts[current_sum] = prefix_counts.get(current_sum, 0) + 1

        return count
`,
      java: `class Solution {
    // Brute force: for each start, extend and track the running sum.
    public int subarraySum(int[] nums, int k) {
        int count = 0;
        int n = nums.length;
        for (int start = 0; start < n; start++) {
            int runningSum = 0;
            for (int end = start; end < n; end++) {
                runningSum += nums[end];
                if (runningSum == k) {
                    count++;
                }
            }
        }
        return count;
    }
}

class SolutionOptimal {
    // Optimal: prefix sums; count how many earlier prefixes equal sum - k.
    public int subarraySum(int[] nums, int k) {
        Map<Integer, Integer> prefixCounts = new HashMap<>();
        prefixCounts.put(0, 1);
        int currentSum = 0;
        int count = 0;

        for (int num : nums) {
            currentSum += num;
            count += prefixCounts.getOrDefault(currentSum - k, 0);
            prefixCounts.put(currentSum, prefixCounts.getOrDefault(currentSum, 0) + 1);
        }

        return count;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: for each start, extend and track the running sum.
    int subarraySum(vector<int>& nums, int k) {
        int count = 0;
        int n = nums.size();
        for (int start = 0; start < n; start++) {
            int runningSum = 0;
            for (int end = start; end < n; end++) {
                runningSum += nums[end];
                if (runningSum == k) {
                    count++;
                }
            }
        }
        return count;
    }
};

class SolutionOptimal {
public:
    // Optimal: prefix sums; count how many earlier prefixes equal sum - k.
    int subarraySum(vector<int>& nums, int k) {
        unordered_map<int, int> prefixCounts;
        prefixCounts[0] = 1;
        int currentSum = 0;
        int count = 0;

        for (int num : nums) {
            currentSum += num;
            if (prefixCounts.count(currentSum - k)) {
                count += prefixCounts[currentSum - k];
            }
            prefixCounts[currentSum]++;
        }

        return count;
    }
};
`,
    },
  },
  {
    problemNumber: 2325,
    title: 'Decode the Message',
    slug: 'decode-the-message',
    difficulty: 'EASY',
    link: 'https://leetcode.com/problems/decode-the-message',
    topics: ['Hash Table', 'String'],
    companies: ['Tesla'],
    frequency: 71.8,
    acceptanceRate: 0.8542,
    problemStatement:
      'You are given the strings key and message, which represent a cipher key and a secret message, respectively. The steps to decode message are as follows:\n\n1. Use the first appearance of all 26 lowercase English letters in key as the order of the substitution table.\n2. Align the substitution table with the regular English alphabet.\n3. Each letter in message is then substituted using the table.\n4. Spaces \' \' are transformed to themselves.\n\nFor example, given key = "happy boy" (actual key would have at least one instance of each letter in the alphabet), we have the partial substitution table of (\'h\' -> \'a\', \'a\' -> \'b\', \'p\' -> \'c\', \'y\' -> \'d\', \'b\' -> \'e\', \'o\' -> \'f\').\n\nReturn the decoded message.\n\nExample 1:\nInput: key = "the quick brown fox jumps over the lazy dog", message = "vkbs bs t suepuv"\nOutput: "this is a secret"\nExplanation: The diagram above shows the substitution table. It is obtained by taking the first appearance of each letter in "the quick brown fox jumps over the lazy dog".\n\nExample 2:\nInput: key = "eljuxhpwnyrdgtqkviszcfmabo", message = "zwx hnrxlqantp mhroujytuj"\nOutput: "the five boxing wizards jump quickly"\n\nConstraints:\n26 <= key.length <= 2000\nmessage.length <= 2000\nkey consists of lowercase English letters and \' \'.\nkey contains every letter of the English alphabet at least once.\nmessage consists of lowercase English letters and \' \'.',
    hints: [
      'Build the substitution table by scanning key once, assigning \'a\', \'b\', \'c\', ... to each new letter you encounter in order.',
      'Skip spaces and letters you have already mapped while building the table.',
      'Then translate message character by character using the table, leaving spaces unchanged.',
    ],
    intuition:
      'This is fundamentally a substitution-cipher lookup, so the heart of the problem is building the right mapping. The rule is that the first time each distinct letter appears in key, it gets the next alphabet letter: the first new letter maps to \'a\', the second new letter to \'b\', and so on. My first instinct - which honestly is also basically the optimal one here - is to walk through key once, and whenever I hit a letter I have not mapped yet, assign it the current alphabet character and advance to the next. A more naive version I could imagine is, for each of the 26 alphabet targets, rescan key to find the corresponding nth distinct letter, but that rescans key repeatedly for no benefit. The key realization is that one pass over key is enough to assign all 26 mappings if I just keep a counter of how many distinct letters I have mapped so far. Once the table is built, decoding message is a trivial character-by-character lookup, leaving spaces untouched.',
    walkthrough:
      'Brute force (repeated scans to find each distinct letter): for the substitution targets \'a\' through \'z\', repeatedly scan key from the start to find the next not-yet-seen distinct letter and map it to the current target, tracking which letters were already used. This rescans key for each target letter, so it is wasteful.\n\nOptimal (single pass to build the table): create an empty map substitution and a variable next_letter starting at \'a\'. Scan key once; for each character that is a lowercase letter not already in substitution, map it to next_letter and advance next_letter to the following alphabet character. Stop early once all 26 are mapped. Then build the result by mapping each character of message: spaces stay as spaces, and every letter is replaced by substitution[letter]. Join and return.',
    complexityAnalysis:
      'Brute force: Time O(26 * |key|) because for each of the 26 target letters we may rescan the whole key; Space O(26) for the mapping and the used-letter set.\n\nOptimal: Time O(|key| + |message|) - one pass to build the table and one pass to translate; Space O(26) for the fixed-size substitution map.',
    solutions: {
      python: `class Solution:
    def decodeMessage(self, key: str, message: str) -> str:
        # Brute force: for each target a..z, rescan key for the next new letter.
        substitution = {}
        used = set()
        for target_ord in range(26):
            target = chr(ord('a') + target_ord)
            for ch in key:
                if ch != ' ' and ch not in used:
                    substitution[ch] = target
                    used.add(ch)
                    break

        decoded = []
        for ch in message:
            decoded.append(' ' if ch == ' ' else substitution[ch])
        return ''.join(decoded)


class SolutionOptimal:
    def decodeMessage(self, key: str, message: str) -> str:
        # Optimal: build the substitution table in one pass over key.
        substitution = {}
        next_letter = ord('a')
        for ch in key:
            if ch != ' ' and ch not in substitution:
                substitution[ch] = chr(next_letter)
                next_letter += 1
                if next_letter > ord('z'):
                    break

        decoded = []
        for ch in message:
            decoded.append(' ' if ch == ' ' else substitution[ch])
        return ''.join(decoded)
`,
      java: `class Solution {
    // Brute force: for each target a..z, rescan key for the next new letter.
    public String decodeMessage(String key, String message) {
        Map<Character, Character> substitution = new HashMap<>();
        Set<Character> used = new HashSet<>();
        for (int t = 0; t < 26; t++) {
            char target = (char) ('a' + t);
            for (char ch : key.toCharArray()) {
                if (ch != ' ' && !used.contains(ch)) {
                    substitution.put(ch, target);
                    used.add(ch);
                    break;
                }
            }
        }

        StringBuilder decoded = new StringBuilder();
        for (char ch : message.toCharArray()) {
            decoded.append(ch == ' ' ? ' ' : substitution.get(ch));
        }
        return decoded.toString();
    }
}

class SolutionOptimal {
    // Optimal: build the substitution table in one pass over key.
    public String decodeMessage(String key, String message) {
        Map<Character, Character> substitution = new HashMap<>();
        char nextLetter = 'a';
        for (char ch : key.toCharArray()) {
            if (ch != ' ' && !substitution.containsKey(ch)) {
                substitution.put(ch, nextLetter);
                nextLetter++;
                if (nextLetter > 'z') {
                    break;
                }
            }
        }

        StringBuilder decoded = new StringBuilder();
        for (char ch : message.toCharArray()) {
            decoded.append(ch == ' ' ? ' ' : substitution.get(ch));
        }
        return decoded.toString();
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: for each target a..z, rescan key for the next new letter.
    string decodeMessage(string key, string message) {
        unordered_map<char, char> substitution;
        unordered_set<char> used;
        for (int t = 0; t < 26; t++) {
            char target = 'a' + t;
            for (char ch : key) {
                if (ch != ' ' && used.find(ch) == used.end()) {
                    substitution[ch] = target;
                    used.insert(ch);
                    break;
                }
            }
        }

        string decoded;
        for (char ch : message) {
            decoded.push_back(ch == ' ' ? ' ' : substitution[ch]);
        }
        return decoded;
    }
};

class SolutionOptimal {
public:
    // Optimal: build the substitution table in one pass over key.
    string decodeMessage(string key, string message) {
        unordered_map<char, char> substitution;
        char nextLetter = 'a';
        for (char ch : key) {
            if (ch != ' ' && substitution.find(ch) == substitution.end()) {
                substitution[ch] = nextLetter;
                nextLetter++;
                if (nextLetter > 'z') {
                    break;
                }
            }
        }

        string decoded;
        for (char ch : message) {
            decoded.push_back(ch == ' ' ? ' ' : substitution[ch]);
        }
        return decoded;
    }
};
`,
    },
  },
  {
    problemNumber: 15,
    title: '3Sum',
    slug: '3sum',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/3sum',
    topics: ['Array', 'Two Pointers', 'Sorting'],
    companies: ['Tesla'],
    frequency: 71.8,
    acceptanceRate: 0.3707,
    problemStatement:
      'Given an integer array nums, return all the triplets [nums[i], nums[j], nums[k]] such that i != j, i != k, and j != k, and nums[i] + nums[j] + nums[k] == 0.\n\nNotice that the solution set must not contain duplicate triplets.\n\nExample 1:\nInput: nums = [-1,0,1,2,-1,-4]\nOutput: [[-1,-1,2],[-1,0,1]]\nExplanation:\nnums[0] + nums[1] + nums[2] = (-1) + 0 + 1 = 0.\nnums[1] + nums[2] + nums[4] = 0 + 1 + (-1) = 0.\nnums[0] + nums[3] + nums[4] = (-1) + 2 + (-1) = 0.\nThe distinct triplets are [-1,0,1] and [-1,-1,2].\nNotice that the order of the output and the order of the triplets does not matter.\n\nExample 2:\nInput: nums = [0,1,1]\nOutput: []\nExplanation: The only possible triplet does not sum up to 0.\n\nExample 3:\nInput: nums = [0,0,0]\nOutput: [[0,0,0]]\nExplanation: The only possible triplet sums up to 0.\n\nConstraints:\n3 <= nums.length <= 3000\n-10^5 <= nums[i] <= 10^5',
    hints: [
      'Fixing one number reduces the problem to finding two other numbers that sum to its negation - a two-sum.',
      'If the array is sorted, you can find those two numbers with a two-pointer scan from both ends in linear time.',
      'Sorting also makes it easy to skip duplicate values so you do not produce duplicate triplets.',
    ],
    intuition:
      'My brain immediately reduces this to a smaller problem I know: if I fix one number, then I just need two other numbers that sum to its negation, which is the classic two-sum. The naive way is three nested loops trying every triplet, checking if they sum to zero, plus some way to dedupe - that is O(n^3) and the deduping is annoying. The key realization is twofold. First, if I sort the array, then for each fixed first element I can find the matching pair using two pointers moving inward from both ends: if the current sum is too small I move the left pointer right to increase it, if too big I move the right pointer left to decrease it. Second, sorting also groups equal values together, which makes skipping duplicates easy - I just advance past repeated values for the fixed element and for the two pointers after I record a triplet. That turns the cubic brute force into an O(n^2) algorithm with clean duplicate handling.',
    walkthrough:
      'Brute force (three nested loops): iterate i < j < k over all triplets, and whenever nums[i] + nums[j] + nums[k] == 0, add the sorted triplet to a set to avoid duplicates. Convert the set to a list at the end. This is O(n^3) and relies on a set for deduplication.\n\nOptimal (sort + two pointers): sort nums. For each index i from 0 upward (stopping when nums[i] > 0 since three sorted non-negative numbers cannot sum to zero), skip i if it duplicates the previous value. Set left = i + 1 and right = n - 1. While left < right, compute total = nums[i] + nums[left] + nums[right]. If total < 0, increment left; if total > 0, decrement right; if total == 0, record the triplet, then advance left past duplicates and decrement right past duplicates before moving both inward. This finds all unique triplets in O(n^2).',
    complexityAnalysis:
      'Brute force: Time O(n^3) for the three nested loops; Space O(number of unique triplets) for the dedup set, which can be significant.\n\nOptimal: Time O(n^2) - the sort is O(n log n) and the outer loop with the inner two-pointer scan is O(n^2), which dominates; Space O(1) extra beyond the output (or O(log n) to O(n) for the sort), with duplicate skipping avoiding any extra dedup structure.',
    solutions: {
      python: `class Solution:
    def threeSum(self, nums):
        # Brute force: check every triplet, dedupe with a set.
        n = len(nums)
        found = set()
        for i in range(n):
            for j in range(i + 1, n):
                for k in range(j + 1, n):
                    if nums[i] + nums[j] + nums[k] == 0:
                        triplet = tuple(sorted((nums[i], nums[j], nums[k])))
                        found.add(triplet)
        return [list(triplet) for triplet in found]


class SolutionOptimal:
    def threeSum(self, nums):
        # Optimal: sort, then fix one element and two-pointer the rest.
        nums.sort()
        n = len(nums)
        result = []

        for i in range(n):
            if nums[i] > 0:
                break  # no way to reach 0 with sorted non-negative numbers
            if i > 0 and nums[i] == nums[i - 1]:
                continue  # skip duplicate first elements
            left = i + 1
            right = n - 1
            while left < right:
                total = nums[i] + nums[left] + nums[right]
                if total < 0:
                    left += 1
                elif total > 0:
                    right -= 1
                else:
                    result.append([nums[i], nums[left], nums[right]])
                    left += 1
                    right -= 1
                    while left < right and nums[left] == nums[left - 1]:
                        left += 1
                    while left < right and nums[right] == nums[right + 1]:
                        right -= 1

        return result
`,
      java: `class Solution {
    // Brute force: check every triplet, dedupe with a set.
    public List<List<Integer>> threeSum(int[] nums) {
        int n = nums.length;
        Set<List<Integer>> found = new HashSet<>();
        for (int i = 0; i < n; i++) {
            for (int j = i + 1; j < n; j++) {
                for (int k = j + 1; k < n; k++) {
                    if (nums[i] + nums[j] + nums[k] == 0) {
                        List<Integer> triplet = new ArrayList<>(
                            Arrays.asList(nums[i], nums[j], nums[k]));
                        Collections.sort(triplet);
                        found.add(triplet);
                    }
                }
            }
        }
        return new ArrayList<>(found);
    }
}

class SolutionOptimal {
    // Optimal: sort, then fix one element and two-pointer the rest.
    public List<List<Integer>> threeSum(int[] nums) {
        Arrays.sort(nums);
        int n = nums.length;
        List<List<Integer>> result = new ArrayList<>();

        for (int i = 0; i < n; i++) {
            if (nums[i] > 0) {
                break;
            }
            if (i > 0 && nums[i] == nums[i - 1]) {
                continue;
            }
            int left = i + 1;
            int right = n - 1;
            while (left < right) {
                int total = nums[i] + nums[left] + nums[right];
                if (total < 0) {
                    left++;
                } else if (total > 0) {
                    right--;
                } else {
                    result.add(Arrays.asList(nums[i], nums[left], nums[right]));
                    left++;
                    right--;
                    while (left < right && nums[left] == nums[left - 1]) {
                        left++;
                    }
                    while (left < right && nums[right] == nums[right + 1]) {
                        right--;
                    }
                }
            }
        }

        return result;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: check every triplet, dedupe with a set.
    vector<vector<int>> threeSum(vector<int>& nums) {
        int n = nums.size();
        set<vector<int>> found;
        for (int i = 0; i < n; i++) {
            for (int j = i + 1; j < n; j++) {
                for (int k = j + 1; k < n; k++) {
                    if (nums[i] + nums[j] + nums[k] == 0) {
                        vector<int> triplet = {nums[i], nums[j], nums[k]};
                        sort(triplet.begin(), triplet.end());
                        found.insert(triplet);
                    }
                }
            }
        }
        return vector<vector<int>>(found.begin(), found.end());
    }
};

class SolutionOptimal {
public:
    // Optimal: sort, then fix one element and two-pointer the rest.
    vector<vector<int>> threeSum(vector<int>& nums) {
        sort(nums.begin(), nums.end());
        int n = nums.size();
        vector<vector<int>> result;

        for (int i = 0; i < n; i++) {
            if (nums[i] > 0) {
                break;
            }
            if (i > 0 && nums[i] == nums[i - 1]) {
                continue;
            }
            int left = i + 1;
            int right = n - 1;
            while (left < right) {
                int total = nums[i] + nums[left] + nums[right];
                if (total < 0) {
                    left++;
                } else if (total > 0) {
                    right--;
                } else {
                    result.push_back({nums[i], nums[left], nums[right]});
                    left++;
                    right--;
                    while (left < right && nums[left] == nums[left - 1]) {
                        left++;
                    }
                    while (left < right && nums[right] == nums[right + 1]) {
                        right--;
                    }
                }
            }
        }

        return result;
    }
};
`,
    },
  },
  {
    problemNumber: 242,
    title: 'Valid Anagram',
    slug: 'valid-anagram',
    difficulty: 'EASY',
    link: 'https://leetcode.com/problems/valid-anagram',
    topics: ['Hash Table', 'String', 'Sorting'],
    companies: ['Tesla'],
    frequency: 64.4,
    acceptanceRate: 0.6666,
    problemStatement:
      'Given two strings s and t, return true if t is an anagram of s, and false otherwise.\n\nExample 1:\nInput: s = "anagram", t = "nagaram"\nOutput: true\n\nExample 2:\nInput: s = "rat", t = "car"\nOutput: false\n\nConstraints:\n1 <= s.length, t.length <= 5 * 10^4\ns and t consist of lowercase English letters.\n\nFollow up: What if the inputs contain Unicode characters? How would you adapt your solution to such a case?',
    hints: [
      'Two strings of different lengths can never be anagrams.',
      'Anagrams use exactly the same letters with the same multiplicities, just in a different order.',
      'You can either sort both strings and compare, or count the frequency of each character and compare the counts.',
    ],
    intuition:
      'An anagram just means the two strings contain the same multiset of characters - same letters, same number of each, order irrelevant. The most obvious idea that pops into my head is to sort both strings and check if the sorted versions are identical; if they use the same letters the same number of times, sorting lines them up exactly. That is clean and correct but costs O(n log n) for the sorting. Then I realize I do not actually need the letters in order - I only need to know the count of each letter. So the better approach is to tally the frequency of each character in s and then decrement those tallies while scanning t; if any count ever goes negative, or the lengths differ, they cannot be anagrams, and if everything cancels out to zero they are. Counting is a single linear pass, which beats sorting. A quick early exit: if the lengths differ they can never be anagrams.',
    walkthrough:
      'Brute force (sort and compare): if the lengths of s and t differ, return false. Otherwise sort the characters of both strings and return whether the two sorted sequences are equal. Sorting dominates the cost.\n\nOptimal (frequency counting): if lengths differ, return false. Build a count array (or map) of size 26 for lowercase letters; increment the count for each character in s and decrement for each character in t. If any count is non-zero at the end, return false; otherwise return true. Equivalently, decrement during the t pass and bail out early if a count goes negative. One linear pass, constant extra space for the fixed alphabet.',
    complexityAnalysis:
      'Brute force: Time O(n log n) to sort both strings of length n; Space O(n) for the sorted character arrays (language dependent).\n\nOptimal: Time O(n) to count characters in a single pass over both strings; Space O(1) for a fixed 26-element count array (or O(k) for k distinct characters if using a map for Unicode).',
    solutions: {
      python: `class Solution:
    def isAnagram(self, s: str, t: str) -> bool:
        # Brute force: sort both strings and compare.
        if len(s) != len(t):
            return False
        return sorted(s) == sorted(t)


class SolutionOptimal:
    def isAnagram(self, s: str, t: str) -> bool:
        # Optimal: count letter frequencies and compare.
        if len(s) != len(t):
            return False
        counts = [0] * 26
        for ch in s:
            counts[ord(ch) - ord('a')] += 1
        for ch in t:
            counts[ord(ch) - ord('a')] -= 1
            if counts[ord(ch) - ord('a')] < 0:
                return False
        return True
`,
      java: `class Solution {
    // Brute force: sort both strings and compare.
    public boolean isAnagram(String s, String t) {
        if (s.length() != t.length()) {
            return false;
        }
        char[] sChars = s.toCharArray();
        char[] tChars = t.toCharArray();
        Arrays.sort(sChars);
        Arrays.sort(tChars);
        return Arrays.equals(sChars, tChars);
    }
}

class SolutionOptimal {
    // Optimal: count letter frequencies and compare.
    public boolean isAnagram(String s, String t) {
        if (s.length() != t.length()) {
            return false;
        }
        int[] counts = new int[26];
        for (int i = 0; i < s.length(); i++) {
            counts[s.charAt(i) - 'a']++;
            counts[t.charAt(i) - 'a']--;
        }
        for (int count : counts) {
            if (count != 0) {
                return false;
            }
        }
        return true;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: sort both strings and compare.
    bool isAnagram(string s, string t) {
        if (s.size() != t.size()) {
            return false;
        }
        sort(s.begin(), s.end());
        sort(t.begin(), t.end());
        return s == t;
    }
};

class SolutionOptimal {
public:
    // Optimal: count letter frequencies and compare.
    bool isAnagram(string s, string t) {
        if (s.size() != t.size()) {
            return false;
        }
        vector<int> counts(26, 0);
        for (int i = 0; i < (int)s.size(); i++) {
            counts[s[i] - 'a']++;
            counts[t[i] - 'a']--;
        }
        for (int count : counts) {
            if (count != 0) {
                return false;
            }
        }
        return true;
    }
};
`,
    },
  },
  {
    problemNumber: 767,
    title: 'Reorganize String',
    slug: 'reorganize-string',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/reorganize-string',
    topics: ['Hash Table', 'String', 'Greedy', 'Sorting', 'Heap (Priority Queue)', 'Counting'],
    companies: ['Tesla'],
    frequency: 64.4,
    acceptanceRate: 0.5620,
    problemStatement:
      'Given a string s, rearrange the characters of s so that any two adjacent characters are not the same.\n\nReturn any possible rearrangement of s or return "" if not possible.\n\nExample 1:\nInput: s = "aab"\nOutput: "aba"\n\nExample 2:\nInput: s = "aaab"\nOutput: ""\n\nConstraints:\n1 <= s.length <= 500\ns consists of lowercase English letters.',
    hints: [
      'If any character appears more than (length + 1) / 2 times, it cannot be separated and the answer is "".',
      'Always place the character that currently has the highest remaining count, as long as it differs from the last placed character.',
      'A max-heap keyed by remaining count lets you efficiently pick the most frequent available character at each step.',
    ],
    intuition:
      'The hard part is making sure no two equal characters end up adjacent. My first instinct is to think greedily: the character that appears most often is the one most at risk of being forced next to itself, so I should place it as early and as spread out as possible. There is also a clear impossibility condition - if some character appears more than half (rounded up) of the total length, there simply are not enough other characters to wedge between its copies, so I return the empty string. For the construction, the key realization is that at each step I want to place the most frequent remaining character that is not the same as the one I just placed. A max-heap keyed by remaining count is the natural tool: I pop the most frequent character, place it, and hold it aside until after I place the next character, so I never place the same character twice in a row. Then I push it back with its decremented count if any remains. This greedy "always use the most abundant that is currently legal" strategy provably works whenever a valid arrangement exists.',
    walkthrough:
      'Brute force (sort by count, interleave into even then odd slots): count the characters, and if the maximum count exceeds (n + 1) / 2 return "". Otherwise sort characters by frequency descending, then fill a result array placing the most frequent characters first into all the even indices (0, 2, 4, ...) and continuing into the odd indices (1, 3, 5, ...). This placement guarantees no two equal characters touch when the impossibility check passes. It is correct but relies on a careful index-filling trick.\n\nOptimal (max-heap greedy): count characters into a map. If any count exceeds (n + 1) / 2, return "". Push all (count, char) pairs into a max-heap ordered by count. Maintain a previous holder (the char just placed, with its leftover count). Repeatedly pop the highest-count character, append it to the result, decrement its count, and if the previously held character still has remaining count, push it back now (so it becomes eligible again, but not adjacent). Then set the held character to the one just placed. Continue until the heap is empty; return the built string.',
    complexityAnalysis:
      'Brute force: Time O(n + k log k) where k is the alphabet size (sorting the counts) plus O(n) to place characters; Space O(n) for the result buffer and counts.\n\nOptimal: Time O(n log k) because each of the n placements does heap operations costing O(log k) on a heap of at most k distinct characters; Space O(k) for the heap and count map (O(1) for a fixed 26-letter alphabet).',
    solutions: {
      python: `import heapq


class Solution:
    def reorganizeString(self, s: str) -> str:
        # Brute force: sort by frequency, fill even indices then odd indices.
        counts = {}
        for ch in s:
            counts[ch] = counts.get(ch, 0) + 1

        n = len(s)
        if max(counts.values()) > (n + 1) // 2:
            return ""

        sorted_chars = sorted(counts.keys(), key=lambda c: counts[c], reverse=True)
        result = [''] * n
        index = 0
        for ch in sorted_chars:
            for _ in range(counts[ch]):
                if index >= n:
                    index = 1  # switch to odd indices once even slots are full
                result[index] = ch
                index += 2
        return ''.join(result)


class SolutionOptimal:
    def reorganizeString(self, s: str) -> str:
        # Optimal: max-heap, always place the most frequent legal character.
        counts = {}
        for ch in s:
            counts[ch] = counts.get(ch, 0) + 1

        n = len(s)
        if max(counts.values()) > (n + 1) // 2:
            return ""

        # Python heap is a min-heap, so store negative counts for max behavior.
        heap = [(-count, ch) for ch, count in counts.items()]
        heapq.heapify(heap)

        result = []
        previous = None  # (remaining_count, char) held from last placement
        while heap:
            count, ch = heapq.heappop(heap)
            result.append(ch)
            if previous and previous[0] < 0:
                heapq.heappush(heap, previous)
            previous = (count + 1, ch)  # count is negative, so +1 decrements magnitude

        return ''.join(result)
`,
      java: `class Solution {
    // Brute force: sort by frequency, fill even indices then odd indices.
    public String reorganizeString(String s) {
        int[] counts = new int[26];
        for (char ch : s.toCharArray()) {
            counts[ch - 'a']++;
        }

        int n = s.length();
        int maxCount = 0;
        for (int c : counts) {
            maxCount = Math.max(maxCount, c);
        }
        if (maxCount > (n + 1) / 2) {
            return "";
        }

        Integer[] order = new Integer[26];
        for (int i = 0; i < 26; i++) {
            order[i] = i;
        }
        Arrays.sort(order, (a, b) -> counts[b] - counts[a]);

        char[] result = new char[n];
        int index = 0;
        for (int letter : order) {
            for (int j = 0; j < counts[letter]; j++) {
                if (index >= n) {
                    index = 1;
                }
                result[index] = (char) ('a' + letter);
                index += 2;
            }
        }
        return new String(result);
    }
}

class SolutionOptimal {
    // Optimal: max-heap, always place the most frequent legal character.
    public String reorganizeString(String s) {
        int[] counts = new int[26];
        for (char ch : s.toCharArray()) {
            counts[ch - 'a']++;
        }
        int n = s.length();

        // Max-heap of [count, charIndex].
        PriorityQueue<int[]> heap = new PriorityQueue<>((a, b) -> b[0] - a[0]);
        for (int i = 0; i < 26; i++) {
            if (counts[i] > 0) {
                if (counts[i] > (n + 1) / 2) {
                    return "";
                }
                heap.offer(new int[] {counts[i], i});
            }
        }

        StringBuilder result = new StringBuilder();
        int[] previous = null; // held [remainingCount, charIndex]
        while (!heap.isEmpty()) {
            int[] top = heap.poll();
            result.append((char) ('a' + top[1]));
            if (previous != null && previous[0] > 0) {
                heap.offer(previous);
            }
            top[0]--;
            previous = top;
        }
        return result.toString();
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: sort by frequency, fill even indices then odd indices.
    string reorganizeString(string s) {
        vector<int> counts(26, 0);
        for (char ch : s) {
            counts[ch - 'a']++;
        }
        int n = s.size();

        int maxCount = 0;
        for (int c : counts) {
            maxCount = max(maxCount, c);
        }
        if (maxCount > (n + 1) / 2) {
            return "";
        }

        vector<int> order(26);
        for (int i = 0; i < 26; i++) {
            order[i] = i;
        }
        sort(order.begin(), order.end(),
             [&](int a, int b) { return counts[a] > counts[b]; });

        string result(n, ' ');
        int index = 0;
        for (int letter : order) {
            for (int j = 0; j < counts[letter]; j++) {
                if (index >= n) {
                    index = 1;
                }
                result[index] = 'a' + letter;
                index += 2;
            }
        }
        return result;
    }
};

class SolutionOptimal {
public:
    // Optimal: max-heap, always place the most frequent legal character.
    string reorganizeString(string s) {
        vector<int> counts(26, 0);
        for (char ch : s) {
            counts[ch - 'a']++;
        }
        int n = s.size();

        // Max-heap of (count, charIndex).
        priority_queue<pair<int, int>> heap;
        for (int i = 0; i < 26; i++) {
            if (counts[i] > 0) {
                if (counts[i] > (n + 1) / 2) {
                    return "";
                }
                heap.push({counts[i], i});
            }
        }

        string result;
        pair<int, int> previous = {0, -1}; // held (remainingCount, charIndex)
        while (!heap.empty()) {
            auto top = heap.top();
            heap.pop();
            result.push_back('a' + top.second);
            if (previous.first > 0) {
                heap.push(previous);
            }
            top.first--;
            previous = top;
        }
        return result;
    }
};
`,
    },
  },
  {
    problemNumber: 695,
    title: 'Max Area of Island',
    slug: 'max-area-of-island',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/max-area-of-island',
    topics: ['Array', 'Depth-First Search', 'Breadth-First Search', 'Union Find', 'Matrix'],
    companies: ['Tesla'],
    frequency: 64.4,
    acceptanceRate: 0.7316,
    problemStatement:
      'You are given an m x n binary matrix grid. An island is a group of 1\'s (representing land) connected 4-directionally (horizontal or vertical). You may assume all four edges of the grid are surrounded by water.\n\nThe area of an island is the number of cells with a value 1 in the island.\n\nReturn the maximum area of an island in grid. If there is no island, return 0.\n\nExample 1:\nInput: grid = [[0,0,1,0,0,0,0,1,0,0,0,0,0],[0,0,0,0,0,0,0,1,1,1,0,0,0],[0,1,1,0,1,0,0,0,0,0,0,0,0],[0,1,0,0,1,1,0,0,1,0,1,0,0],[0,1,0,0,1,1,0,0,1,1,1,0,0],[0,0,0,0,0,0,0,0,0,0,1,0,0],[0,0,0,0,0,0,0,1,1,1,0,0,0],[0,0,0,0,0,0,0,1,1,0,0,0,0]]\nOutput: 6\nExplanation: The answer is not 11, because the island must be connected 4-directionally.\n\nExample 2:\nInput: grid = [[0,0,0,0,0,0,0,0]]\nOutput: 0\n\nConstraints:\nm == grid.length\nn == grid[i].length\n1 <= m, n <= 50\ngrid[i][j] is either 0 or 1.',
    hints: [
      'Every time you find an unvisited land cell, it begins a new island whose area you need to measure.',
      'Flood fill from that cell, counting cells as you go, and mark visited cells so you do not count them twice.',
      'Track the maximum island area seen across all starting cells.',
    ],
    intuition:
      'This is the cousin of counting islands, except instead of counting how many there are, I want the size of the biggest one. The same flood-fill insight applies: each unvisited land cell is the seed of an island, and I can measure that island by walking out to every connected land cell and counting them. My first instinct is to use a separate visited matrix so I do not double-count, and from each new land cell run a BFS that tallies the cells - that is the clean naive version. The realization that makes the optimal version a touch leaner is that I can mark a cell as visited simply by overwriting it to 0 during a DFS, so I do not need a second matrix. Either way the count from each flood fill gives me one island\'s area, and I keep a running maximum across all islands. The DFS version returns the area of the island rooted at a cell as 1 (for itself) plus the areas returned by recursing into its four neighbors that are still land.',
    walkthrough:
      'Brute force (BFS with a visited matrix): keep a visited 2D array. Scan every cell; when a cell is land and unvisited, run a BFS that counts cells, enqueuing unvisited land neighbors and marking them visited, accumulating an area; update max_area with that island\'s area. Uses extra O(m*n) space for the visited grid.\n\nOptimal (in-place DFS): scan every cell; when grid[r][c] == 1, call a recursive dfs(r, c) that returns 0 if out of bounds or water, otherwise sets grid[r][c] = 0 (marking it visited) and returns 1 plus the sum of dfs on its four neighbors. Update max_area with each returned island area. Overwriting cells to 0 avoids any separate visited structure.',
    complexityAnalysis:
      'Brute force (BFS + visited): Time O(m*n) since each cell is enqueued/dequeued once; Space O(m*n) for the visited matrix plus the BFS queue.\n\nOptimal (in-place DFS): Time O(m*n) because each cell is visited a constant number of times; Space O(m*n) worst case for the recursion stack (an all-land grid), but no separate visited matrix is needed.',
    solutions: {
      python: `from collections import deque


class Solution:
    def maxAreaOfIsland(self, grid):
        # Brute force: BFS flood fill with a separate visited matrix.
        rows = len(grid)
        cols = len(grid[0])
        visited = [[False] * cols for _ in range(rows)]
        max_area = 0

        for r in range(rows):
            for c in range(cols):
                if grid[r][c] == 1 and not visited[r][c]:
                    area = 0
                    queue = deque([(r, c)])
                    visited[r][c] = True
                    while queue:
                        cr, cc = queue.popleft()
                        area += 1
                        for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                            nr, nc = cr + dr, cc + dc
                            if 0 <= nr < rows and 0 <= nc < cols:
                                if grid[nr][nc] == 1 and not visited[nr][nc]:
                                    visited[nr][nc] = True
                                    queue.append((nr, nc))
                    max_area = max(max_area, area)

        return max_area


class SolutionOptimal:
    def maxAreaOfIsland(self, grid):
        # Optimal: in-place DFS that returns each island's area.
        rows = len(grid)
        cols = len(grid[0])

        def dfs(r, c):
            if r < 0 or r >= rows or c < 0 or c >= cols or grid[r][c] == 0:
                return 0
            grid[r][c] = 0  # mark visited
            return 1 + dfs(r - 1, c) + dfs(r + 1, c) + dfs(r, c - 1) + dfs(r, c + 1)

        max_area = 0
        for r in range(rows):
            for c in range(cols):
                if grid[r][c] == 1:
                    max_area = max(max_area, dfs(r, c))
        return max_area
`,
      java: `class Solution {
    // Brute force: BFS flood fill with a separate visited matrix.
    public int maxAreaOfIsland(int[][] grid) {
        int rows = grid.length;
        int cols = grid[0].length;
        boolean[][] visited = new boolean[rows][cols];
        int maxArea = 0;
        int[][] directions = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}};

        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (grid[r][c] == 1 && !visited[r][c]) {
                    int area = 0;
                    Queue<int[]> queue = new LinkedList<>();
                    queue.add(new int[] {r, c});
                    visited[r][c] = true;
                    while (!queue.isEmpty()) {
                        int[] cell = queue.poll();
                        area++;
                        for (int[] d : directions) {
                            int nr = cell[0] + d[0];
                            int nc = cell[1] + d[1];
                            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols
                                    && grid[nr][nc] == 1 && !visited[nr][nc]) {
                                visited[nr][nc] = true;
                                queue.add(new int[] {nr, nc});
                            }
                        }
                    }
                    maxArea = Math.max(maxArea, area);
                }
            }
        }

        return maxArea;
    }
}

class SolutionOptimal {
    // Optimal: in-place DFS that returns each island's area.
    public int maxAreaOfIsland(int[][] grid) {
        int maxArea = 0;
        for (int r = 0; r < grid.length; r++) {
            for (int c = 0; c < grid[0].length; c++) {
                if (grid[r][c] == 1) {
                    maxArea = Math.max(maxArea, dfs(grid, r, c));
                }
            }
        }
        return maxArea;
    }

    private int dfs(int[][] grid, int r, int c) {
        if (r < 0 || r >= grid.length || c < 0 || c >= grid[0].length
                || grid[r][c] == 0) {
            return 0;
        }
        grid[r][c] = 0; // mark visited
        return 1 + dfs(grid, r - 1, c) + dfs(grid, r + 1, c)
                 + dfs(grid, r, c - 1) + dfs(grid, r, c + 1);
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: BFS flood fill with a separate visited matrix.
    int maxAreaOfIsland(vector<vector<int>>& grid) {
        int rows = grid.size();
        int cols = grid[0].size();
        vector<vector<bool>> visited(rows, vector<bool>(cols, false));
        int maxArea = 0;
        int directions[4][2] = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}};

        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (grid[r][c] == 1 && !visited[r][c]) {
                    int area = 0;
                    queue<pair<int, int>> q;
                    q.push({r, c});
                    visited[r][c] = true;
                    while (!q.empty()) {
                        auto cell = q.front();
                        q.pop();
                        area++;
                        for (auto& d : directions) {
                            int nr = cell.first + d[0];
                            int nc = cell.second + d[1];
                            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols
                                    && grid[nr][nc] == 1 && !visited[nr][nc]) {
                                visited[nr][nc] = true;
                                q.push({nr, nc});
                            }
                        }
                    }
                    maxArea = max(maxArea, area);
                }
            }
        }

        return maxArea;
    }
};

class SolutionOptimal {
public:
    // Optimal: in-place DFS that returns each island's area.
    int maxAreaOfIsland(vector<vector<int>>& grid) {
        int maxArea = 0;
        for (int r = 0; r < (int)grid.size(); r++) {
            for (int c = 0; c < (int)grid[0].size(); c++) {
                if (grid[r][c] == 1) {
                    maxArea = max(maxArea, dfs(grid, r, c));
                }
            }
        }
        return maxArea;
    }

private:
    int dfs(vector<vector<int>>& grid, int r, int c) {
        if (r < 0 || r >= (int)grid.size() || c < 0 || c >= (int)grid[0].size()
                || grid[r][c] == 0) {
            return 0;
        }
        grid[r][c] = 0; // mark visited
        return 1 + dfs(grid, r - 1, c) + dfs(grid, r + 1, c)
                 + dfs(grid, r, c - 1) + dfs(grid, r, c + 1);
    }
};
`,
    },
  },
  {
    problemNumber: 53,
    title: 'Maximum Subarray',
    slug: 'maximum-subarray',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/maximum-subarray',
    topics: ['Array', 'Divide and Conquer', 'Dynamic Programming'],
    companies: ['Tesla'],
    frequency: 64.4,
    acceptanceRate: 0.5210,
    problemStatement:
      'Given an integer array nums, find the subarray with the largest sum, and return its sum.\n\nExample 1:\nInput: nums = [-2,1,-3,4,-1,2,1,-5,4]\nOutput: 6\nExplanation: The subarray [4,-1,2,1] has the largest sum 6.\n\nExample 2:\nInput: nums = [1]\nOutput: 1\nExplanation: The subarray [1] has the largest sum 1.\n\nExample 3:\nInput: nums = [5,4,-1,7,8]\nOutput: 23\nExplanation: The subarray [5,4,-1,7,8] has the largest sum 23.\n\nConstraints:\n1 <= nums.length <= 10^5\n-10^4 <= nums[i] <= 10^4\n\nFollow up: If you have figured out the O(n) solution, try coding another solution using the divide and conquer approach, which is more subtle.',
    hints: [
      'For each ending position, ask what the best subarray sum ending exactly there is.',
      'A subarray ending at i either extends the best subarray ending at i-1, or starts fresh at i - whichever is larger.',
      'Keep a running best-ending-here value and a global maximum; this is Kadane\'s algorithm.',
    ],
    intuition:
      'The brute force is the obvious starting point: try every subarray, sum it, and keep the maximum. With a running sum per start, that is O(n^2). To do better, I ask a sharper question: for each index, what is the best subarray sum that ends exactly at this index? That framing is powerful because a subarray ending at i is built from a subarray ending at i-1 plus the current element - or it is just the current element starting fresh. The key realization is that if the best sum ending at i-1 is negative, it can only hurt me, so I should drop it and start a new subarray at i. So current_best = max(nums[i], current_best + nums[i]). I track the largest current_best I ever see as the global answer. This is Kadane\'s algorithm, and it runs in a single linear pass with constant space because each step only needs the previous "best ending here" value, not the whole history.',
    walkthrough:
      'Brute force (all subarrays): for each start index, accumulate a running sum over end indices and update max_sum whenever the running sum is larger. Using the running sum keeps it O(n^2) rather than O(n^3).\n\nOptimal (Kadane\'s algorithm): keep current_best, the best subarray sum ending at the current index, and max_sum, the best seen overall. Initialize both to nums[0]. For each subsequent element, set current_best = max(num, current_best + num) - either extend the previous best-ending-here subarray or restart at the current element. Update max_sum = max(max_sum, current_best). Return max_sum after the pass.',
    complexityAnalysis:
      'Brute force: Time O(n^2) from iterating all start/end pairs with a running sum; Space O(1) for the running maximum.\n\nOptimal: Time O(n) for the single pass; Space O(1) because we only retain the best-ending-here value and the global maximum.',
    solutions: {
      python: `class Solution:
    def maxSubArray(self, nums):
        # Brute force: try every subarray using a running sum per start.
        max_sum = nums[0]
        n = len(nums)
        for start in range(n):
            running_sum = 0
            for end in range(start, n):
                running_sum += nums[end]
                max_sum = max(max_sum, running_sum)
        return max_sum


class SolutionOptimal:
    def maxSubArray(self, nums):
        # Optimal: Kadane's algorithm; best subarray ending at each index.
        current_best = nums[0]
        max_sum = nums[0]

        for num in nums[1:]:
            current_best = max(num, current_best + num)
            max_sum = max(max_sum, current_best)

        return max_sum
`,
      java: `class Solution {
    // Brute force: try every subarray using a running sum per start.
    public int maxSubArray(int[] nums) {
        int maxSum = nums[0];
        int n = nums.length;
        for (int start = 0; start < n; start++) {
            int runningSum = 0;
            for (int end = start; end < n; end++) {
                runningSum += nums[end];
                maxSum = Math.max(maxSum, runningSum);
            }
        }
        return maxSum;
    }
}

class SolutionOptimal {
    // Optimal: Kadane's algorithm; best subarray ending at each index.
    public int maxSubArray(int[] nums) {
        int currentBest = nums[0];
        int maxSum = nums[0];

        for (int i = 1; i < nums.length; i++) {
            currentBest = Math.max(nums[i], currentBest + nums[i]);
            maxSum = Math.max(maxSum, currentBest);
        }

        return maxSum;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: try every subarray using a running sum per start.
    int maxSubArray(vector<int>& nums) {
        int maxSum = nums[0];
        int n = nums.size();
        for (int start = 0; start < n; start++) {
            int runningSum = 0;
            for (int end = start; end < n; end++) {
                runningSum += nums[end];
                maxSum = max(maxSum, runningSum);
            }
        }
        return maxSum;
    }
};

class SolutionOptimal {
public:
    // Optimal: Kadane's algorithm; best subarray ending at each index.
    int maxSubArray(vector<int>& nums) {
        int currentBest = nums[0];
        int maxSum = nums[0];

        for (int i = 1; i < (int)nums.size(); i++) {
            currentBest = max(nums[i], currentBest + nums[i]);
            maxSum = max(maxSum, currentBest);
        }

        return maxSum;
    }
};
`,
    },
  },
  {
    problemNumber: 341,
    title: 'Flatten Nested List Iterator',
    slug: 'flatten-nested-list-iterator',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/flatten-nested-list-iterator',
    topics: ['Stack', 'Tree', 'Depth-First Search', 'Design', 'Queue', 'Iterator'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.6523,
    problemStatement:
      'You are given a nested list of integers nestedList. Each element is either an integer or a list whose elements may also be integers or other lists. Implement an iterator to flatten it.\n\nImplement the NestedIterator class:\n- NestedIterator(List<NestedInteger> nestedList) Initializes the iterator with the nested list nestedList.\n- int next() Returns the next integer in the nested list.\n- boolean hasNext() Returns true if there are still some integers in the nested list and false otherwise.\n\nYour code will be tested with the following pseudocode:\ninitialize iterator with nestedList\nres = []\nwhile iterator.hasNext()\n    append iterator.next() to the end of res\nreturn res\n\nIf res matches the expected flattened list, then your code will be judged as correct.\n\nExample 1:\nInput: nestedList = [[1,1],2,[1,1]]\nOutput: [1,1,2,1,1]\nExplanation: By calling next repeatedly until hasNext returns false, the order of elements returned by next should be: [1,1,2,1,1].\n\nExample 2:\nInput: nestedList = [1,[4,[6]]]\nOutput: [1,4,6]\n\nConstraints:\n1 <= nestedList.length <= 500\nThe values of the integers in the nested list is in the range [-10^6, 10^6].',
    hints: [
      'One approach is to recursively flatten everything into a simple list up front, then iterate that list.',
      'A more lazy approach uses a stack so you only unwrap nested lists as the caller asks for elements.',
      'Push elements onto the stack in reverse so the top of the stack is the next item; expand any list on top before returning an integer.',
    ],
    intuition:
      'The structure here is really a tree - integers are leaves and lists are internal nodes - and "flatten" means produce the leaves in left-to-right order, which is just a depth-first traversal. The most direct idea that comes to mind is to do all that work in the constructor: recursively walk the whole nested structure once, collecting every integer into a plain flat list, and then next/hasNext just iterate over that list with an index. That is dead simple and correct, and it is my brute-force design. The downside is that I eagerly process the entire structure even if the caller only asks for a few elements. The lazier, more iterator-idiomatic design uses a stack: I push the top-level elements (in reverse so the first one ends up on top), and on demand I peek at the top; if it is a list I pop it and push its children in reverse, repeating until an integer is on top. That way I only unwrap as much as needed to answer each call. The key realization is that flattening is a DFS, and a stack lets me run that DFS incrementally instead of all at once.',
    walkthrough:
      'Brute force (eager flatten in constructor): in the constructor, recursively traverse nestedList; for each element, if it is an integer append it to a list flat, otherwise recurse into its sublist. Keep an index position. next() returns flat[position] and advances position; hasNext() returns whether position < len(flat). Simple but does all the work up front and stores every integer.\n\nOptimal (lazy stack-based): in the constructor push the top-level NestedInteger elements onto a stack in reverse order (so the first element is on top). hasNext() first makes the top a valid integer: while the stack is non-empty and the top is a list, pop it and push its elements in reverse order; return whether the stack is non-empty. next() calls hasNext() to ensure an integer is on top, then pops and returns that integer. This only expands nested lists as needed.',
    complexityAnalysis:
      'Brute force: constructor is O(N) where N is the total count of integers across the whole structure (it flattens everything); next() and hasNext() are O(1); Space O(N) to store the fully flattened list plus O(D) recursion depth.\n\nOptimal: each integer is pushed and popped a constant number of times, so the total work across all next/hasNext calls is O(N) amortized, with each individual call amortized O(1); Space O(N) worst case for the stack (e.g. a flat list pushes everything), but work is deferred until requested.',
    solutions: {
      python: `# """
# This is the interface that allows for creating nested lists.
# class NestedInteger:
#    def isInteger(self) -> bool: ...
#    def getInteger(self) -> int: ...
#    def getList(self) -> [NestedInteger]: ...
# """


class Solution:
    # Brute force: recursively flatten everything in the constructor.
    def __init__(self, nestedList):
        self.flat = []
        self._flatten(nestedList)
        self.position = 0

    def _flatten(self, nested_list):
        for element in nested_list:
            if element.isInteger():
                self.flat.append(element.getInteger())
            else:
                self._flatten(element.getList())

    def next(self) -> int:
        value = self.flat[self.position]
        self.position += 1
        return value

    def hasNext(self) -> bool:
        return self.position < len(self.flat)


class SolutionOptimal:
    # Optimal: lazy stack that only unwraps lists when needed.
    def __init__(self, nestedList):
        # Push in reverse so the first element ends up on top.
        self.stack = list(reversed(nestedList))

    def next(self) -> int:
        self.hasNext()  # ensure an integer is on top
        return self.stack.pop().getInteger()

    def hasNext(self) -> bool:
        while self.stack and not self.stack[-1].isInteger():
            nested = self.stack.pop().getList()
            for element in reversed(nested):
                self.stack.append(element)
        return len(self.stack) > 0
`,
      java: `/**
 * // This is the interface that allows for creating nested lists.
 * public interface NestedInteger {
 *     public boolean isInteger();
 *     public Integer getInteger();
 *     public List<NestedInteger> getList();
 * }
 */
class Solution implements Iterator<Integer> {
    // Brute force: recursively flatten everything in the constructor.
    private List<Integer> flat = new ArrayList<>();
    private int position = 0;

    public Solution(List<NestedInteger> nestedList) {
        flatten(nestedList);
    }

    private void flatten(List<NestedInteger> nestedList) {
        for (NestedInteger element : nestedList) {
            if (element.isInteger()) {
                flat.add(element.getInteger());
            } else {
                flatten(element.getList());
            }
        }
    }

    public Integer next() {
        return flat.get(position++);
    }

    public boolean hasNext() {
        return position < flat.size();
    }
}

class SolutionOptimal implements Iterator<Integer> {
    // Optimal: lazy stack that only unwraps lists when needed.
    private Deque<NestedInteger> stack = new ArrayDeque<>();

    public SolutionOptimal(List<NestedInteger> nestedList) {
        // Push in reverse so the first element ends up on top.
        for (int i = nestedList.size() - 1; i >= 0; i--) {
            stack.push(nestedList.get(i));
        }
    }

    public Integer next() {
        hasNext(); // ensure an integer is on top
        return stack.pop().getInteger();
    }

    public boolean hasNext() {
        while (!stack.isEmpty() && !stack.peek().isInteger()) {
            List<NestedInteger> nested = stack.pop().getList();
            for (int i = nested.size() - 1; i >= 0; i--) {
                stack.push(nested.get(i));
            }
        }
        return !stack.isEmpty();
    }
}
`,
      cpp: `/**
 * // This is the interface that allows for creating nested lists.
 * class NestedInteger {
 *   public:
 *     bool isInteger() const;
 *     int getInteger() const;
 *     const vector<NestedInteger> &getList() const;
 * };
 */
class Solution {
    // Brute force: recursively flatten everything in the constructor.
private:
    vector<int> flat;
    int position = 0;

    void flatten(const vector<NestedInteger>& nestedList) {
        for (const NestedInteger& element : nestedList) {
            if (element.isInteger()) {
                flat.push_back(element.getInteger());
            } else {
                flatten(element.getList());
            }
        }
    }

public:
    Solution(vector<NestedInteger>& nestedList) {
        flatten(nestedList);
    }

    int next() {
        return flat[position++];
    }

    bool hasNext() {
        return position < (int)flat.size();
    }
};

class SolutionOptimal {
    // Optimal: lazy stack that only unwraps lists when needed.
private:
    vector<NestedInteger> stack;

public:
    SolutionOptimal(vector<NestedInteger>& nestedList) {
        // Push in reverse so the first element ends up on top.
        for (int i = nestedList.size() - 1; i >= 0; i--) {
            stack.push_back(nestedList[i]);
        }
    }

    int next() {
        hasNext(); // ensure an integer is on top
        int value = stack.back().getInteger();
        stack.pop_back();
        return value;
    }

    bool hasNext() {
        while (!stack.empty() && !stack.back().isInteger()) {
            vector<NestedInteger> nested = stack.back().getList();
            stack.pop_back();
            for (int i = nested.size() - 1; i >= 0; i--) {
                stack.push_back(nested[i]);
            }
        }
        return !stack.empty();
    }
};
`,
    },
  },
  {
    problemNumber: 1275,
    title: 'Find Winner on a Tic Tac Toe Game',
    slug: 'find-winner-on-a-tic-tac-toe-game',
    difficulty: 'EASY',
    link: 'https://leetcode.com/problems/find-winner-on-a-tic-tac-toe-game',
    topics: ['Array', 'Hash Table', 'Matrix', 'Simulation'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.5418,
    problemStatement:
      'Tic-tac-toe is played by two players A and B on a 3 x 3 grid. The rules of tic-tac-toe are:\n- Players take turns placing characters into empty squares \' \'.\n- The first player A always places \'X\' characters, while the second player B always places \'O\' characters.\n- \'X\' and \'O\' characters are always placed into empty squares, never filled ones.\n- The game ends when there are three of the same (non-empty) character filling any row, column, or diagonal.\n- The game also ends if all squares are non-empty.\n- No more moves can be played if the game is over.\n\nGiven a 2D integer array moves where moves[i] = [row_i, col_i] indicates that the ith move will be played on grid[row_i][col_i] (the ith move is played by A if i is even, and by B if i is odd), return the winner of the game if it exists (A or B). In case the game ends in a draw, return "Draw". If there are still movements to play, return "Pending".\n\nExample 1:\nInput: moves = [[0,0],[2,0],[1,1],[2,1],[2,2]]\nOutput: "A"\nExplanation: A wins, they always play first.\n\nExample 2:\nInput: moves = [[0,0],[1,1],[0,1],[0,2],[1,0],[2,0]]\nOutput: "B"\nExplanation: B wins.\n\nExample 3:\nInput: moves = [[0,0],[1,1],[2,0],[1,0],[1,2],[2,1],[0,1],[0,2],[2,2]]\nOutput: "Draw"\n\nConstraints:\n1 <= moves.length <= 9\nmoves[i].length == 2\n0 <= row_i, col_i <= 2\nThere are no repeated elements on moves.\nmoves follow the rules of tic-tac-toe.',
    hints: [
      'Player A makes the even-indexed moves; player B makes the odd-indexed moves.',
      'After placing the marks, check all 8 winning lines (3 rows, 3 columns, 2 diagonals) for three matching marks.',
      'If no one has won, it is a "Draw" when all 9 squares are filled, otherwise "Pending".',
    ],
    intuition:
      'This is a simulation, so the straightforward thing is to actually replay the moves onto a 3x3 board and then check who won. My first instinct is exactly that brute force: build the grid, place A on even-indexed moves and B on odd-indexed moves, then scan all eight winning lines (three rows, three columns, two diagonals) to see if any is filled with one player\'s mark. With only nine cells this is trivially fast. The slightly cleverer realization, since the board is fixed at 3x3, is that I do not even need the full grid - I can keep running sums per row, per column, and for the two diagonals, adding +1 for A\'s marks and -1 for B\'s. Any line whose absolute sum reaches 3 means one player filled it: +3 means A, -3 means B. That avoids building or rescanning the grid and decides the winner the moment a line completes. After processing, if no one hit 3, it is a Draw when all nine squares were used and Pending otherwise.',
    walkthrough:
      'Brute force (build grid, scan all lines): create a 3x3 grid of blanks. Replay moves, writing \'X\' on even indices and \'O\' on odd indices. Then check each of the 8 winning lines for three equal non-blank marks; if found, return "A" for X or "B" for O. If no winner, return "Draw" when len(moves) == 9, else "Pending".\n\nOptimal (running line sums): keep arrays row_sums[3] and col_sums[3], plus diagonal and anti_diagonal sums. For move i at (r, c), let player = +1 if i is even (A) else -1 (B). Add player to row_sums[r], col_sums[c], to diagonal if r == c, and to anti_diagonal if r + c == 2. If any of those reaches +3 return "A" or -3 return "B" immediately. After all moves, return "Draw" if 9 moves were played, otherwise "Pending".',
    complexityAnalysis:
      'Brute force: Time O(1) in practice - replaying up to 9 moves and scanning 8 fixed lines is constant (formally O(m) for m moves on a constant-size board); Space O(1) for the fixed 3x3 grid.\n\nOptimal: Time O(m) where m is the number of moves (at most 9), updating a constant number of sums per move; Space O(1) for the fixed-size row, column, and diagonal sum trackers.',
    solutions: {
      python: `class Solution:
    def tictactoe(self, moves):
        # Brute force: replay moves onto a grid, then scan all winning lines.
        grid = [[' '] * 3 for _ in range(3)]
        for i, (r, c) in enumerate(moves):
            grid[r][c] = 'X' if i % 2 == 0 else 'O'

        lines = []
        for i in range(3):
            lines.append([grid[i][0], grid[i][1], grid[i][2]])  # rows
            lines.append([grid[0][i], grid[1][i], grid[2][i]])  # columns
        lines.append([grid[0][0], grid[1][1], grid[2][2]])      # diagonal
        lines.append([grid[0][2], grid[1][1], grid[2][0]])      # anti-diagonal

        for line in lines:
            if line[0] != ' ' and line[0] == line[1] == line[2]:
                return 'A' if line[0] == 'X' else 'B'

        return 'Draw' if len(moves) == 9 else 'Pending'


class SolutionOptimal:
    def tictactoe(self, moves):
        # Optimal: track running sums per row/column/diagonal.
        row_sums = [0, 0, 0]
        col_sums = [0, 0, 0]
        diagonal = 0
        anti_diagonal = 0

        for i, (r, c) in enumerate(moves):
            player = 1 if i % 2 == 0 else -1
            row_sums[r] += player
            col_sums[c] += player
            if r == c:
                diagonal += player
            if r + c == 2:
                anti_diagonal += player

            if (abs(row_sums[r]) == 3 or abs(col_sums[c]) == 3
                    or abs(diagonal) == 3 or abs(anti_diagonal) == 3):
                return 'A' if player == 1 else 'B'

        return 'Draw' if len(moves) == 9 else 'Pending'
`,
      java: `class Solution {
    // Brute force: replay moves onto a grid, then scan all winning lines.
    public String tictactoe(int[][] moves) {
        char[][] grid = new char[3][3];
        for (char[] row : grid) {
            Arrays.fill(row, ' ');
        }
        for (int i = 0; i < moves.length; i++) {
            int r = moves[i][0];
            int c = moves[i][1];
            grid[r][c] = (i % 2 == 0) ? 'X' : 'O';
        }

        char[][] lines = new char[8][3];
        int idx = 0;
        for (int i = 0; i < 3; i++) {
            lines[idx++] = new char[] {grid[i][0], grid[i][1], grid[i][2]};
            lines[idx++] = new char[] {grid[0][i], grid[1][i], grid[2][i]};
        }
        lines[idx++] = new char[] {grid[0][0], grid[1][1], grid[2][2]};
        lines[idx++] = new char[] {grid[0][2], grid[1][1], grid[2][0]};

        for (char[] line : lines) {
            if (line[0] != ' ' && line[0] == line[1] && line[1] == line[2]) {
                return (line[0] == 'X') ? "A" : "B";
            }
        }

        return moves.length == 9 ? "Draw" : "Pending";
    }
}

class SolutionOptimal {
    // Optimal: track running sums per row/column/diagonal.
    public String tictactoe(int[][] moves) {
        int[] rowSums = new int[3];
        int[] colSums = new int[3];
        int diagonal = 0;
        int antiDiagonal = 0;

        for (int i = 0; i < moves.length; i++) {
            int r = moves[i][0];
            int c = moves[i][1];
            int player = (i % 2 == 0) ? 1 : -1;
            rowSums[r] += player;
            colSums[c] += player;
            if (r == c) {
                diagonal += player;
            }
            if (r + c == 2) {
                antiDiagonal += player;
            }

            if (Math.abs(rowSums[r]) == 3 || Math.abs(colSums[c]) == 3
                    || Math.abs(diagonal) == 3 || Math.abs(antiDiagonal) == 3) {
                return (player == 1) ? "A" : "B";
            }
        }

        return moves.length == 9 ? "Draw" : "Pending";
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: replay moves onto a grid, then scan all winning lines.
    string tictactoe(vector<vector<int>>& moves) {
        vector<vector<char>> grid(3, vector<char>(3, ' '));
        for (int i = 0; i < (int)moves.size(); i++) {
            int r = moves[i][0];
            int c = moves[i][1];
            grid[r][c] = (i % 2 == 0) ? 'X' : 'O';
        }

        vector<array<char, 3>> lines;
        for (int i = 0; i < 3; i++) {
            lines.push_back({grid[i][0], grid[i][1], grid[i][2]});
            lines.push_back({grid[0][i], grid[1][i], grid[2][i]});
        }
        lines.push_back({grid[0][0], grid[1][1], grid[2][2]});
        lines.push_back({grid[0][2], grid[1][1], grid[2][0]});

        for (auto& line : lines) {
            if (line[0] != ' ' && line[0] == line[1] && line[1] == line[2]) {
                return (line[0] == 'X') ? "A" : "B";
            }
        }

        return moves.size() == 9 ? "Draw" : "Pending";
    }
};

class SolutionOptimal {
public:
    // Optimal: track running sums per row/column/diagonal.
    string tictactoe(vector<vector<int>>& moves) {
        vector<int> rowSums(3, 0);
        vector<int> colSums(3, 0);
        int diagonal = 0;
        int antiDiagonal = 0;

        for (int i = 0; i < (int)moves.size(); i++) {
            int r = moves[i][0];
            int c = moves[i][1];
            int player = (i % 2 == 0) ? 1 : -1;
            rowSums[r] += player;
            colSums[c] += player;
            if (r == c) {
                diagonal += player;
            }
            if (r + c == 2) {
                antiDiagonal += player;
            }

            if (abs(rowSums[r]) == 3 || abs(colSums[c]) == 3
                    || abs(diagonal) == 3 || abs(antiDiagonal) == 3) {
                return (player == 1) ? "A" : "B";
            }
        }

        return moves.size() == 9 ? "Draw" : "Pending";
    }
};
`,
    },
  },
  {
    problemNumber: 42,
    title: 'Trapping Rain Water',
    slug: 'trapping-rain-water',
    difficulty: 'HARD',
    link: 'https://leetcode.com/problems/trapping-rain-water',
    topics: ['Array', 'Two Pointers', 'Dynamic Programming', 'Stack', 'Monotonic Stack'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.6510,
    problemStatement:
      'Given n non-negative integers representing an elevation map where the width of each bar is 1, compute how much water it can trap after raining.\n\nExample 1:\nInput: height = [0,1,0,2,1,0,1,3,2,1,2,1]\nOutput: 6\nExplanation: The above elevation map (black section) is represented by array [0,1,0,2,1,0,1,3,2,1,2,1]. In this case, 6 units of rain water (blue section) are being trapped.\n\nExample 2:\nInput: height = [4,2,0,3,2,5]\nOutput: 9\n\nConstraints:\nn == height.length\n1 <= n <= 2 * 10^4\n0 <= height[i] <= 10^5',
    hints: [
      'The water sitting above any single bar is determined by the tallest bars to its left and right.',
      'Water above index i = min(max height to its left, max height to its right) - height[i], if positive.',
      'You can precompute left-max and right-max arrays, or use two pointers moving inward driven by the smaller side.',
    ],
    intuition:
      'The mental picture is key: water sitting on top of a particular bar is held in place by walls on both sides, and how high it can pool is set by the shorter of the two tallest walls - the tallest bar to its left and the tallest bar to its right. So the water above index i is min(left_max, right_max) - height[i], counting only when that is positive. My first brute-force instinct is, for each index, to scan left to find the max on the left and scan right to find the max on the right, then apply that formula - clearly correct but O(n^2) because of those repeated scans. The first optimization is to precompute, in two passes, the running left-max and right-max for every index, turning it into O(n) time and O(n) space. The deeper realization that gets me to O(1) space is the two-pointer trick: I move a pointer from each end inward, and whichever side currently has the smaller running max is the side that determines the water level there - so I can safely process that side and advance it, because the opposite side already has something at least as tall guaranteeing the bound.',
    walkthrough:
      'Brute force (scan for max on each side per index): for each index i, scan left to find left_max and right to find right_max, then add max(0, min(left_max, right_max) - height[i]) to the total. Two inner scans per index make it O(n^2).\n\nOptimal (two pointers): set left = 0, right = n - 1, and track left_max and right_max seen so far. While left < right, compare height[left] and height[right]. If height[left] < height[right], the left side bounds the water, so update left_max and add left_max - height[left] to the total, then advance left. Otherwise the right side bounds it, so update right_max and add right_max - height[right], then move right inward. Because we always process the smaller side, the chosen side\'s max is guaranteed to be the true limiting wall. This runs in one pass with O(1) extra space.',
    complexityAnalysis:
      'Brute force: Time O(n^2) because for every bar we scan left and right for the maxima; Space O(1).\n\nOptimal (two pointers): Time O(n) since left and right together traverse the array once; Space O(1) for the two pointers and the two running maxima. (A precomputed left-max/right-max array variant is also O(n) time but O(n) space.)',
    solutions: {
      python: `class Solution:
    def trap(self, height):
        # Brute force: for each bar, scan both sides for the tallest walls.
        n = len(height)
        total = 0
        for i in range(n):
            left_max = 0
            for j in range(i + 1):
                left_max = max(left_max, height[j])
            right_max = 0
            for j in range(i, n):
                right_max = max(right_max, height[j])
            water = min(left_max, right_max) - height[i]
            if water > 0:
                total += water
        return total


class SolutionOptimal:
    def trap(self, height):
        # Optimal: two pointers driven by the smaller running max.
        left = 0
        right = len(height) - 1
        left_max = 0
        right_max = 0
        total = 0

        while left < right:
            if height[left] < height[right]:
                left_max = max(left_max, height[left])
                total += left_max - height[left]
                left += 1
            else:
                right_max = max(right_max, height[right])
                total += right_max - height[right]
                right -= 1

        return total
`,
      java: `class Solution {
    // Brute force: for each bar, scan both sides for the tallest walls.
    public int trap(int[] height) {
        int n = height.length;
        int total = 0;
        for (int i = 0; i < n; i++) {
            int leftMax = 0;
            for (int j = 0; j <= i; j++) {
                leftMax = Math.max(leftMax, height[j]);
            }
            int rightMax = 0;
            for (int j = i; j < n; j++) {
                rightMax = Math.max(rightMax, height[j]);
            }
            int water = Math.min(leftMax, rightMax) - height[i];
            if (water > 0) {
                total += water;
            }
        }
        return total;
    }
}

class SolutionOptimal {
    // Optimal: two pointers driven by the smaller running max.
    public int trap(int[] height) {
        int left = 0;
        int right = height.length - 1;
        int leftMax = 0;
        int rightMax = 0;
        int total = 0;

        while (left < right) {
            if (height[left] < height[right]) {
                leftMax = Math.max(leftMax, height[left]);
                total += leftMax - height[left];
                left++;
            } else {
                rightMax = Math.max(rightMax, height[right]);
                total += rightMax - height[right];
                right--;
            }
        }

        return total;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: for each bar, scan both sides for the tallest walls.
    int trap(vector<int>& height) {
        int n = height.size();
        int total = 0;
        for (int i = 0; i < n; i++) {
            int leftMax = 0;
            for (int j = 0; j <= i; j++) {
                leftMax = max(leftMax, height[j]);
            }
            int rightMax = 0;
            for (int j = i; j < n; j++) {
                rightMax = max(rightMax, height[j]);
            }
            int water = min(leftMax, rightMax) - height[i];
            if (water > 0) {
                total += water;
            }
        }
        return total;
    }
};

class SolutionOptimal {
public:
    // Optimal: two pointers driven by the smaller running max.
    int trap(vector<int>& height) {
        int left = 0;
        int right = height.size() - 1;
        int leftMax = 0;
        int rightMax = 0;
        int total = 0;

        while (left < right) {
            if (height[left] < height[right]) {
                leftMax = max(leftMax, height[left]);
                total += leftMax - height[left];
                left++;
            } else {
                rightMax = max(rightMax, height[right]);
                total += rightMax - height[right];
                right--;
            }
        }

        return total;
    }
};
`,
    },
  },
  {
    problemNumber: 224,
    title: 'Basic Calculator',
    slug: 'basic-calculator',
    difficulty: 'HARD',
    link: 'https://leetcode.com/problems/basic-calculator',
    topics: ['Math', 'String', 'Stack', 'Recursion'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.4559,
    problemStatement:
      'Given a string s representing a valid expression, implement a basic calculator to evaluate it, and return the result of the evaluation.\n\nNote: You are not allowed to use any built-in function which evaluates strings as mathematical expressions, such as eval().\n\nExample 1:\nInput: s = "1 + 1"\nOutput: 2\n\nExample 2:\nInput: s = " 2-1 + 2 "\nOutput: 3\n\nExample 3:\nInput: s = "(1+(4+5+2)-3)+(6+8)"\nOutput: 23\n\nConstraints:\n1 <= s.length <= 3 * 10^5\ns consists of digits, \'+\', \'-\', \'(\', \')\', and \' \'.\ns represents a valid expression.\n\'+\' is not used as a unary operation (i.e., "+1" and "+(2 + 3)" is invalid).\n\'-\' could be used as a unary operation (i.e., "-1" and "-(2 + 3)" is valid).\nThere will be no two consecutive operators in the input.\nEvery number and running calculation will fit in a signed 32-bit integer.',
    hints: [
      'There is no multiplication or division here, just addition, subtraction, and parentheses.',
      'A running result and a current sign (+1 or -1) let you process a flat expression left to right.',
      'When you hit \'(\', push the result so far and the sign onto a stack; on \')\', combine the inner result back with what you pushed.',
    ],
    intuition:
      'Without multiplication or division, the only real complication is the parentheses, which can nest arbitrarily. For a flat expression like "2 - 1 + 2", I can just keep a running result and a current sign: each number is added with its sign, and a \'-\' flips the next sign to negative. The naive thought is to handle parentheses by recursion - find a matching paren, evaluate the inside, substitute - but matching parens and re-parsing substrings is fiddly. The cleaner realization is that I can process the whole string in one left-to-right pass using a stack to remember the context outside each set of parentheses. When I encounter \'(\', I push the current running result and the current sign, then reset result to 0 and sign to +1 to start evaluating the sub-expression fresh. When I hit \')\', the running result is the value of the parenthesized group, so I multiply it by the sign I pushed and add it to the result I pushed, restoring the outer context. Numbers and +/- are handled exactly as in the flat case. One pass, a single stack, and the parentheses just save and restore state.',
    walkthrough:
      'Brute force (recursive descent on parentheses): write a recursive evaluator that scans the string; when it sees \'(\' it recursively evaluates until the matching \')\' and uses that value as a number, otherwise it accumulates numbers with the current sign. This is correct but requires carefully tracking the parse position across recursive calls and re-entering at the right index.\n\nOptimal (single pass with a stack): keep result (running total), sign (+1 or -1, current sign), and a stack. Scan each character: build multi-digit numbers from consecutive digits and, when the number ends, add sign * number to result and reset number. For \'+\' set sign = +1; for \'-\' set sign = -1. For \'(\' push result then sign onto the stack, and reset result = 0, sign = +1 to evaluate the group. For \')\' finalize any pending value, then pop the saved sign and saved result and set result = saved_result + saved_sign * result. Spaces are skipped. Return result at the end (adding any trailing number).',
    complexityAnalysis:
      'Brute force (recursion): Time O(n) overall since each character is parsed a constant number of times, but with recursion overhead per parenthesis group; Space O(n) for the recursion stack on deeply nested parentheses.\n\nOptimal: Time O(n) for the single scan; Space O(n) for the stack, which holds two values per open parenthesis in the worst case of deep nesting.',
    solutions: {
      python: `class Solution:
    def calculate(self, s: str) -> int:
        # Brute force: recursive descent handling parentheses.
        def helper(index):
            result = 0
            sign = 1
            number = 0
            while index < len(s):
                ch = s[index]
                if ch.isdigit():
                    number = number * 10 + int(ch)
                elif ch == '+':
                    result += sign * number
                    number = 0
                    sign = 1
                elif ch == '-':
                    result += sign * number
                    number = 0
                    sign = -1
                elif ch == '(':
                    inner_value, index = helper(index + 1)
                    number = inner_value
                elif ch == ')':
                    result += sign * number
                    return result, index
                index += 1
            result += sign * number
            return result, index

        value, _ = helper(0)
        return value


class SolutionOptimal:
    def calculate(self, s: str) -> int:
        # Optimal: single pass with a stack to save/restore outer context.
        result = 0
        sign = 1
        number = 0
        stack = []

        for ch in s:
            if ch.isdigit():
                number = number * 10 + int(ch)
            elif ch == '+':
                result += sign * number
                number = 0
                sign = 1
            elif ch == '-':
                result += sign * number
                number = 0
                sign = -1
            elif ch == '(':
                stack.append(result)
                stack.append(sign)
                result = 0
                sign = 1
            elif ch == ')':
                result += sign * number
                number = 0
                saved_sign = stack.pop()
                saved_result = stack.pop()
                result = saved_result + saved_sign * result

        return result + sign * number
`,
      java: `class Solution {
    // Brute force: recursive descent handling parentheses.
    private int position;

    public int calculate(String s) {
        position = 0;
        return helper(s);
    }

    private int helper(String s) {
        int result = 0;
        int sign = 1;
        int number = 0;
        while (position < s.length()) {
            char ch = s.charAt(position);
            if (Character.isDigit(ch)) {
                number = number * 10 + (ch - '0');
            } else if (ch == '+') {
                result += sign * number;
                number = 0;
                sign = 1;
            } else if (ch == '-') {
                result += sign * number;
                number = 0;
                sign = -1;
            } else if (ch == '(') {
                position++;
                number = helper(s);
            } else if (ch == ')') {
                result += sign * number;
                return result;
            }
            position++;
        }
        result += sign * number;
        return result;
    }
}

class SolutionOptimal {
    // Optimal: single pass with a stack to save/restore outer context.
    public int calculate(String s) {
        int result = 0;
        int sign = 1;
        int number = 0;
        Deque<Integer> stack = new ArrayDeque<>();

        for (int i = 0; i < s.length(); i++) {
            char ch = s.charAt(i);
            if (Character.isDigit(ch)) {
                number = number * 10 + (ch - '0');
            } else if (ch == '+') {
                result += sign * number;
                number = 0;
                sign = 1;
            } else if (ch == '-') {
                result += sign * number;
                number = 0;
                sign = -1;
            } else if (ch == '(') {
                stack.push(result);
                stack.push(sign);
                result = 0;
                sign = 1;
            } else if (ch == ')') {
                result += sign * number;
                number = 0;
                int savedSign = stack.pop();
                int savedResult = stack.pop();
                result = savedResult + savedSign * result;
            }
        }

        return result + sign * number;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: recursive descent handling parentheses.
    int calculate(string s) {
        position = 0;
        return helper(s);
    }

private:
    int position;

    int helper(const string& s) {
        int result = 0;
        int sign = 1;
        int number = 0;
        while (position < (int)s.size()) {
            char ch = s[position];
            if (isdigit(ch)) {
                number = number * 10 + (ch - '0');
            } else if (ch == '+') {
                result += sign * number;
                number = 0;
                sign = 1;
            } else if (ch == '-') {
                result += sign * number;
                number = 0;
                sign = -1;
            } else if (ch == '(') {
                position++;
                number = helper(s);
            } else if (ch == ')') {
                result += sign * number;
                return result;
            }
            position++;
        }
        result += sign * number;
        return result;
    }
};

class SolutionOptimal {
public:
    // Optimal: single pass with a stack to save/restore outer context.
    int calculate(string s) {
        long long result = 0;
        int sign = 1;
        long long number = 0;
        vector<int> stack;

        for (char ch : s) {
            if (isdigit(ch)) {
                number = number * 10 + (ch - '0');
            } else if (ch == '+') {
                result += sign * number;
                number = 0;
                sign = 1;
            } else if (ch == '-') {
                result += sign * number;
                number = 0;
                sign = -1;
            } else if (ch == '(') {
                stack.push_back((int)result);
                stack.push_back(sign);
                result = 0;
                sign = 1;
            } else if (ch == ')') {
                result += sign * number;
                number = 0;
                int savedSign = stack.back();
                stack.pop_back();
                int savedResult = stack.back();
                stack.pop_back();
                result = savedResult + savedSign * result;
            }
        }

        return (int)(result + sign * number);
    }
};
`,
    },
  },
  {
    problemNumber: 41,
    title: 'First Missing Positive',
    slug: 'first-missing-positive',
    difficulty: 'HARD',
    link: 'https://leetcode.com/problems/first-missing-positive',
    topics: ['Array', 'Hash Table'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.4108,
    problemStatement:
      'Given an unsorted integer array nums, return the smallest missing positive integer.\n\nYou must implement an algorithm that runs in O(n) time and uses O(1) auxiliary space.\n\nExample 1:\nInput: nums = [1,2,0]\nOutput: 3\nExplanation: The numbers in the range [1,2] are all in the array.\n\nExample 2:\nInput: nums = [3,4,-1,1]\nOutput: 2\nExplanation: 1 is in the array but 2 is missing.\n\nExample 3:\nInput: nums = [7,8,9,11,12]\nOutput: 1\nExplanation: The smallest positive integer 1 is missing.\n\nConstraints:\n1 <= nums.length <= 10^5\n-2^31 <= nums[i] <= 2^31 - 1',
    hints: [
      'For an array of length n, the answer must be in the range [1, n+1] - values outside that range do not matter.',
      'You can use the array itself as a hash table by placing each value v in the position index v-1.',
      'After placing each in-range value at its home index, the first index whose value does not match index+1 reveals the missing positive.',
    ],
    intuition:
      'The first thing I realize is that the answer is tightly bounded: with n numbers, the smallest missing positive can be at most n+1 (that happens when the array is exactly 1..n). So only values in the range 1..n actually matter; anything else I can ignore. The easy brute force is to throw all values into a hash set and then check 1, 2, 3, ... until I find one missing - that is O(n) time but O(n) space, and the problem demands O(1) space. The key realization that unlocks O(1) space is that I can use the array itself as a hash table by "cyclic sorting": the value v wants to live at index v-1. So I walk the array and, whenever nums[i] is in range and not already at its home index, I swap it into place; I repeat the swap at position i until the element there is either out of range or already home. After this placement pass, I scan once more, and the first index i where nums[i] != i+1 tells me i+1 is the missing positive. If everything is in place, the answer is n+1.',
    walkthrough:
      'Brute force (hash set): insert every value into a set. Then check integers starting at 1, returning the first one not present in the set. O(n) time but O(n) extra space, which violates the O(1) space requirement.\n\nOptimal (cyclic sort in place): for each index i, while nums[i] is in the range [1, n] and nums[i] is not already at its target (nums[nums[i] - 1] != nums[i]), swap nums[i] to its home index nums[i] - 1. This places each in-range value v at index v-1. Then scan the array; the first index i where nums[i] != i + 1 means i + 1 is missing, so return it. If all positions match, every value 1..n is present, so return n + 1. The swap-until-settled loop ensures O(n) total swaps because each swap puts at least one value permanently in its correct slot.',
    complexityAnalysis:
      'Brute force: Time O(n) to build the set and scan; Space O(n) for the set - fails the O(1) space requirement.\n\nOptimal: Time O(n) because each element is moved to its home index at most once (each swap finalizes one value), so the total number of swaps is bounded by n; Space O(1) since all rearrangement happens in place within the input array.',
    solutions: {
      python: `class Solution:
    def firstMissingPositive(self, nums):
        # Brute force: hash set then scan 1, 2, 3, ... (uses O(n) space).
        present = set(nums)
        candidate = 1
        while candidate in present:
            candidate += 1
        return candidate


class SolutionOptimal:
    def firstMissingPositive(self, nums):
        # Optimal: cyclic sort - place value v at index v - 1 in place.
        n = len(nums)
        for i in range(n):
            # keep swapping nums[i] to its home index until it settles
            while 1 <= nums[i] <= n and nums[nums[i] - 1] != nums[i]:
                target = nums[i] - 1
                nums[i], nums[target] = nums[target], nums[i]

        for i in range(n):
            if nums[i] != i + 1:
                return i + 1
        return n + 1
`,
      java: `class Solution {
    // Brute force: hash set then scan 1, 2, 3, ... (uses O(n) space).
    public int firstMissingPositive(int[] nums) {
        Set<Integer> present = new HashSet<>();
        for (int num : nums) {
            present.add(num);
        }
        int candidate = 1;
        while (present.contains(candidate)) {
            candidate++;
        }
        return candidate;
    }
}

class SolutionOptimal {
    // Optimal: cyclic sort - place value v at index v - 1 in place.
    public int firstMissingPositive(int[] nums) {
        int n = nums.length;
        for (int i = 0; i < n; i++) {
            while (nums[i] >= 1 && nums[i] <= n
                    && nums[nums[i] - 1] != nums[i]) {
                int target = nums[i] - 1;
                int temp = nums[target];
                nums[target] = nums[i];
                nums[i] = temp;
            }
        }

        for (int i = 0; i < n; i++) {
            if (nums[i] != i + 1) {
                return i + 1;
            }
        }
        return n + 1;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: hash set then scan 1, 2, 3, ... (uses O(n) space).
    int firstMissingPositive(vector<int>& nums) {
        unordered_set<int> present(nums.begin(), nums.end());
        int candidate = 1;
        while (present.count(candidate)) {
            candidate++;
        }
        return candidate;
    }
};

class SolutionOptimal {
public:
    // Optimal: cyclic sort - place value v at index v - 1 in place.
    int firstMissingPositive(vector<int>& nums) {
        int n = nums.size();
        for (int i = 0; i < n; i++) {
            while (nums[i] >= 1 && nums[i] <= n
                    && nums[nums[i] - 1] != nums[i]) {
                int target = nums[i] - 1;
                swap(nums[i], nums[target]);
            }
        }

        for (int i = 0; i < n; i++) {
            if (nums[i] != i + 1) {
                return i + 1;
            }
        }
        return n + 1;
    }
};
`,
    },
  },
  {
    problemNumber: 187,
    title: 'Repeated DNA Sequences',
    slug: 'repeated-dna-sequences',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/repeated-dna-sequences',
    topics: ['Hash Table', 'String', 'Bit Manipulation', 'Sliding Window', 'Rolling Hash', 'Hash Function'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.5132,
    problemStatement:
      'The DNA sequence is composed of a series of nucleotides abbreviated as \'A\', \'C\', \'G\', and \'T\'.\n\nFor example, "ACGAATTCCG" is a DNA sequence.\n\nWhen studying DNA, it is useful to identify repeated sequences within the DNA.\n\nGiven a string s that represents a DNA sequence, return all the 10-letter-long sequences (substrings) that occur more than once in a DNA molecule. You may return the answer in any order.\n\nExample 1:\nInput: s = "AAAAACCCCCAAAAACCCCCCAAAAAGGGTTT"\nOutput: ["AAAAACCCCC","CCCCCAAAAA"]\n\nExample 2:\nInput: s = "AAAAAAAAAAAAA"\nOutput: ["AAAAAAAAAA"]\n\nConstraints:\n1 <= s.length <= 10^5\ns[i] is either \'A\', \'C\', \'G\', or \'T\'.',
    hints: [
      'Slide a window of length 10 across the string and look at every 10-letter substring.',
      'Use a hash map (or set) to count how many times each 10-letter substring has appeared.',
      'A substring should be added to the answer exactly once, the second time you see it.',
    ],
    intuition:
      'The task is just: among all length-10 windows, which substrings show up more than once? My first instinct is the direct sliding window: take every 10-character substring, count occurrences in a hash map, and report the ones that appear at least twice. To make sure I add each repeated sequence exactly once, I add it to the result the moment its count hits 2. That is clean and, because each substring is a fixed length of 10, slicing is cheap-ish. The thing that nags me is that hashing a 10-character string repeatedly costs work proportional to its length each time. The optimization is to encode each window as a compact integer rather than a string: since there are only 4 nucleotides, I can map A, C, G, T to two bits each, so a 10-letter window fits in 20 bits. As the window slides one character, I can roll the encoding - shift out the leftmost 2 bits and shift in the new character\'s 2 bits - updating in O(1). Then I store and count those integers instead of strings, which keeps the hashing constant per step.',
    walkthrough:
      'Brute force (substring hash map): slide a window of length 10 from index 0 to len(s) - 10. For each window, extract the 10-character substring and increment its count in a map seen_counts. The first time a substring\'s count becomes 2, add it to the result. Return the result. Correct, but each substring extraction and hash is O(10).\n\nOptimal (rolling 2-bit encoding): map each nucleotide to 2 bits (A=0, C=1, G=2, T=3). Build the encoding of the first 10-character window, then slide: for each new character, update the encoding as ((encoding << 2) | char_bits) & mask, where mask keeps only the low 20 bits (dropping the character that left the window). Track counts of these integer encodings in a map; when an encoding\'s count reaches 2, append the corresponding substring (the current 10-character window) to the result. This makes each window update and hash O(1).',
    complexityAnalysis:
      'Brute force: Time O(n * 10) = O(n) treating 10 as a constant, but with a real factor of 10 per window for extracting and hashing each substring; Space O(n) for the map of substrings (each key is 10 characters).\n\nOptimal (rolling hash): Time O(n) with an O(1) update per window since the encoding is rolled in constant time; Space O(n) for the map of integer encodings, but each key is a single integer rather than a 10-character string, so the constant factor is smaller.',
    solutions: {
      python: `class Solution:
    def findRepeatedDnaSequences(self, s: str):
        # Brute force: count every 10-letter substring in a hash map.
        if len(s) < 10:
            return []
        seen_counts = {}
        result = []
        for start in range(len(s) - 9):
            window = s[start:start + 10]
            seen_counts[window] = seen_counts.get(window, 0) + 1
            if seen_counts[window] == 2:
                result.append(window)
        return result


class SolutionOptimal:
    def findRepeatedDnaSequences(self, s: str):
        # Optimal: rolling 2-bit encoding of each 10-letter window.
        if len(s) < 10:
            return []
        char_to_bits = {'A': 0, 'C': 1, 'G': 2, 'T': 3}
        mask = (1 << 20) - 1  # keep only the low 20 bits (10 chars * 2 bits)

        encoding = 0
        for i in range(10):
            encoding = (encoding << 2) | char_to_bits[s[i]]

        seen_counts = {encoding: 1}
        result = []
        for start in range(1, len(s) - 9):
            new_char = char_to_bits[s[start + 9]]
            encoding = ((encoding << 2) | new_char) & mask
            seen_counts[encoding] = seen_counts.get(encoding, 0) + 1
            if seen_counts[encoding] == 2:
                result.append(s[start:start + 10])
        return result
`,
      java: `class Solution {
    // Brute force: count every 10-letter substring in a hash map.
    public List<String> findRepeatedDnaSequences(String s) {
        List<String> result = new ArrayList<>();
        if (s.length() < 10) {
            return result;
        }
        Map<String, Integer> seenCounts = new HashMap<>();
        for (int start = 0; start + 10 <= s.length(); start++) {
            String window = s.substring(start, start + 10);
            int count = seenCounts.getOrDefault(window, 0) + 1;
            seenCounts.put(window, count);
            if (count == 2) {
                result.add(window);
            }
        }
        return result;
    }
}

class SolutionOptimal {
    // Optimal: rolling 2-bit encoding of each 10-letter window.
    public List<String> findRepeatedDnaSequences(String s) {
        List<String> result = new ArrayList<>();
        if (s.length() < 10) {
            return result;
        }
        Map<Character, Integer> charToBits = new HashMap<>();
        charToBits.put('A', 0);
        charToBits.put('C', 1);
        charToBits.put('G', 2);
        charToBits.put('T', 3);
        int mask = (1 << 20) - 1;

        int encoding = 0;
        for (int i = 0; i < 10; i++) {
            encoding = (encoding << 2) | charToBits.get(s.charAt(i));
        }

        Map<Integer, Integer> seenCounts = new HashMap<>();
        seenCounts.put(encoding, 1);
        for (int start = 1; start + 10 <= s.length(); start++) {
            int newChar = charToBits.get(s.charAt(start + 9));
            encoding = ((encoding << 2) | newChar) & mask;
            int count = seenCounts.getOrDefault(encoding, 0) + 1;
            seenCounts.put(encoding, count);
            if (count == 2) {
                result.add(s.substring(start, start + 10));
            }
        }
        return result;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: count every 10-letter substring in a hash map.
    vector<string> findRepeatedDnaSequences(string s) {
        vector<string> result;
        if (s.size() < 10) {
            return result;
        }
        unordered_map<string, int> seenCounts;
        for (int start = 0; start + 10 <= (int)s.size(); start++) {
            string window = s.substr(start, 10);
            seenCounts[window]++;
            if (seenCounts[window] == 2) {
                result.push_back(window);
            }
        }
        return result;
    }
};

class SolutionOptimal {
public:
    // Optimal: rolling 2-bit encoding of each 10-letter window.
    vector<string> findRepeatedDnaSequences(string s) {
        vector<string> result;
        if (s.size() < 10) {
            return result;
        }
        unordered_map<char, int> charToBits = {
            {'A', 0}, {'C', 1}, {'G', 2}, {'T', 3}
        };
        int mask = (1 << 20) - 1;

        int encoding = 0;
        for (int i = 0; i < 10; i++) {
            encoding = (encoding << 2) | charToBits[s[i]];
        }

        unordered_map<int, int> seenCounts;
        seenCounts[encoding] = 1;
        for (int start = 1; start + 10 <= (int)s.size(); start++) {
            int newChar = charToBits[s[start + 9]];
            encoding = ((encoding << 2) | newChar) & mask;
            seenCounts[encoding]++;
            if (seenCounts[encoding] == 2) {
                result.push_back(s.substr(start, 10));
            }
        }
        return result;
    }
};
`,
    },
  },
  {
    problemNumber: 346,
    title: 'Moving Average from Data Stream',
    slug: 'moving-average-from-data-stream',
    difficulty: 'EASY',
    link: 'https://leetcode.com/problems/moving-average-from-data-stream',
    topics: ['Array', 'Design', 'Queue', 'Data Stream'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.7994,
    problemStatement:
      'Given a stream of integers and a window size, calculate the moving average of all integers in the sliding window.\n\nImplement the MovingAverage class:\n- MovingAverage(int size) Initializes the object with the size of the window size.\n- double next(int val) Returns the moving average of the last size values of the stream.\n\nExample 1:\nInput\n["MovingAverage", "next", "next", "next", "next"]\n[[3], [1], [10], [3], [5]]\nOutput\n[null, 1.0, 5.5, 4.66667, 6.0]\nExplanation\nMovingAverage movingAverage = new MovingAverage(3);\nmovingAverage.next(1); // return 1.0 = 1 / 1\nmovingAverage.next(10); // return 5.5 = (1 + 10) / 2\nmovingAverage.next(3); // return 4.66667 = (1 + 10 + 3) / 3\nmovingAverage.next(5); // return 6.0 = (10 + 3 + 5) / 3\n\nConstraints:\n1 <= size <= 1000\n-10^5 <= val <= 10^5\nAt most 10^4 calls will be made to next.',
    hints: [
      'You only ever average the most recent size values, so older values can be discarded.',
      'A queue holds the current window; when it exceeds size, drop the oldest element.',
      'Maintain a running sum so each next call avoids re-adding the whole window.',
    ],
    intuition:
      'The window only ever cares about the last size values, so as soon as a value falls out of the window it is irrelevant. My first instinct is to just keep a list of everything I have seen and, on each next call, take the last size elements and average them by summing them up. That is correct but it re-sums the whole window every single call, which is wasteful. The key realization is two-fold: I only need to retain the values currently inside the window, and I do not need to recompute the sum from scratch. A queue is the perfect structure for "drop the oldest when a new one arrives" - I enqueue the new value, and if the queue now exceeds size I dequeue the oldest. To make each call O(1), I maintain a running window_sum: when I add a value I add it to the sum, and when I evict the oldest I subtract it. Then the moving average is just window_sum divided by the current number of elements in the queue.',
    walkthrough:
      'Brute force (store all, re-sum last size): keep a list values of every value seen. On next(val), append val, then take the slice of the last size elements, sum them, and divide by how many there are. Correct but each call re-sums up to size elements, so calls are O(size).\n\nOptimal (queue + running sum): keep a queue window and a running window_sum, plus the fixed size. On next(val), add val to window_sum and enqueue it. If the queue length now exceeds size, dequeue the oldest value and subtract it from window_sum. Return window_sum divided by the current queue length. Each call does O(1) work.',
    complexityAnalysis:
      'Brute force: next is O(size) because it re-sums up to size elements each call; Space O(n) since it retains every value ever seen.\n\nOptimal: next is O(1) - one enqueue, at most one dequeue, and a couple of arithmetic updates; Space O(size) for the queue holding only the current window plus the running sum.',
    solutions: {
      python: `from collections import deque


class Solution:
    # Brute force: store all values and re-sum the last 'size' each call.
    def __init__(self, size: int):
        self.size = size
        self.values = []

    def next(self, val: int) -> float:
        self.values.append(val)
        window = self.values[-self.size:]
        return sum(window) / len(window)


class SolutionOptimal:
    # Optimal: queue of the current window plus a running sum.
    def __init__(self, size: int):
        self.size = size
        self.window = deque()
        self.window_sum = 0

    def next(self, val: int) -> float:
        self.window_sum += val
        self.window.append(val)
        if len(self.window) > self.size:
            self.window_sum -= self.window.popleft()
        return self.window_sum / len(self.window)
`,
      java: `class Solution {
    // Brute force: store all values and re-sum the last 'size' each call.
    private int size;
    private List<Integer> values;

    public Solution(int size) {
        this.size = size;
        this.values = new ArrayList<>();
    }

    public double next(int val) {
        values.add(val);
        int start = Math.max(0, values.size() - size);
        int sum = 0;
        for (int i = start; i < values.size(); i++) {
            sum += values.get(i);
        }
        int count = values.size() - start;
        return (double) sum / count;
    }
}

class SolutionOptimal {
    // Optimal: queue of the current window plus a running sum.
    private int size;
    private Queue<Integer> window;
    private double windowSum;

    public SolutionOptimal(int size) {
        this.size = size;
        this.window = new LinkedList<>();
        this.windowSum = 0;
    }

    public double next(int val) {
        windowSum += val;
        window.offer(val);
        if (window.size() > size) {
            windowSum -= window.poll();
        }
        return windowSum / window.size();
    }
}
`,
      cpp: `class Solution {
    // Brute force: store all values and re-sum the last 'size' each call.
private:
    int size;
    vector<int> values;

public:
    Solution(int size) : size(size) {}

    double next(int val) {
        values.push_back(val);
        int start = max(0, (int)values.size() - size);
        int sum = 0;
        for (int i = start; i < (int)values.size(); i++) {
            sum += values[i];
        }
        int count = (int)values.size() - start;
        return (double) sum / count;
    }
};

class SolutionOptimal {
    // Optimal: queue of the current window plus a running sum.
private:
    int size;
    queue<int> window;
    double windowSum;

public:
    SolutionOptimal(int size) : size(size), windowSum(0) {}

    double next(int val) {
        windowSum += val;
        window.push(val);
        if ((int)window.size() > size) {
            windowSum -= window.front();
            window.pop();
        }
        return windowSum / window.size();
    }
};
`,
    },
  },
  {
    problemNumber: 49,
    title: 'Group Anagrams',
    slug: 'group-anagrams',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/group-anagrams',
    topics: ['Array', 'Hash Table', 'String', 'Sorting'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.7093,
    problemStatement:
      'Given an array of strings strs, group the anagrams together. You can return the answer in any order.\n\nExample 1:\nInput: strs = ["eat","tea","tan","ate","nat","bat"]\nOutput: [["bat"],["nat","tan"],["ate","eat","tea"]]\nExplanation:\nThere is no string in strs that can be rearranged to form "bat".\nThe strings "nat" and "tan" are anagrams as they can be rearranged to form each other.\nThe strings "ate", "eat", and "tea" are anagrams as they can be rearranged to form each other.\n\nExample 2:\nInput: strs = [""]\nOutput: [[""]]\n\nExample 3:\nInput: strs = ["a"]\nOutput: [["a"]]\n\nConstraints:\n1 <= strs.length <= 10^4\n0 <= strs[i].length <= 100\nstrs[i] consists of lowercase English letters.',
    hints: [
      'Anagrams share the same letters with the same counts, so they need a canonical signature that is identical for all of them.',
      'Sorting the characters of a string gives such a signature - all anagrams sort to the same string.',
      'Group strings by that signature using a hash map from signature to the list of original strings.',
    ],
    intuition:
      'The defining property is that two strings are anagrams exactly when they contain the same multiset of letters. So if I can compute a canonical key that is identical for all anagrams of each other but different across groups, I can just bucket strings by that key in a hash map. My first instinct for the key is to sort each string\'s characters - "eat", "tea", and "ate" all sort to "aet", so they collide into the same bucket naturally. That works and is easy to write. The only inefficiency is that sorting each string costs O(L log L). The realization for the optimal key is that since the alphabet is just 26 lowercase letters, I can instead use the letter-count vector as the signature: count how many of each letter the string has and turn that count tuple into a key. Two strings are anagrams precisely when their count vectors match, and building a count vector is O(L) instead of O(L log L). Either way the structure is the same: map signature to a list of original strings, then return the lists.',
    walkthrough:
      'Brute force (sorted-string key): create a map groups from a signature to a list of strings. For each string, sort its characters to form the signature, then append the original string to groups[signature]. Return the map\'s values. Correct; the per-string cost is dominated by sorting.\n\nOptimal (character-count key): create the same kind of map. For each string, build a count array of length 26 by tallying each character, then turn that array into a hashable key (e.g. a tuple or a delimited string). Append the original string under that key. Return the lists. The count signature is built in O(L), avoiding the sort, so it is asymptotically faster per string.',
    complexityAnalysis:
      'Brute force: Time O(n * L log L) where n is the number of strings and L is the maximum string length - each string is sorted; Space O(n * L) for the map storing all strings and signatures.\n\nOptimal: Time O(n * L) because each string\'s 26-length count signature is built in linear time with no sort; Space O(n * L) for the map of groups and the count keys.',
    solutions: {
      python: `class Solution:
    def groupAnagrams(self, strs):
        # Brute force: use the sorted characters as the grouping key.
        groups = {}
        for word in strs:
            signature = ''.join(sorted(word))
            if signature not in groups:
                groups[signature] = []
            groups[signature].append(word)
        return list(groups.values())


class SolutionOptimal:
    def groupAnagrams(self, strs):
        # Optimal: use the 26-letter count vector as the grouping key.
        groups = {}
        for word in strs:
            counts = [0] * 26
            for ch in word:
                counts[ord(ch) - ord('a')] += 1
            signature = tuple(counts)
            if signature not in groups:
                groups[signature] = []
            groups[signature].append(word)
        return list(groups.values())
`,
      java: `class Solution {
    // Brute force: use the sorted characters as the grouping key.
    public List<List<String>> groupAnagrams(String[] strs) {
        Map<String, List<String>> groups = new HashMap<>();
        for (String word : strs) {
            char[] chars = word.toCharArray();
            Arrays.sort(chars);
            String signature = new String(chars);
            groups.computeIfAbsent(signature, key -> new ArrayList<>()).add(word);
        }
        return new ArrayList<>(groups.values());
    }
}

class SolutionOptimal {
    // Optimal: use the 26-letter count vector as the grouping key.
    public List<List<String>> groupAnagrams(String[] strs) {
        Map<String, List<String>> groups = new HashMap<>();
        for (String word : strs) {
            int[] counts = new int[26];
            for (char ch : word.toCharArray()) {
                counts[ch - 'a']++;
            }
            StringBuilder keyBuilder = new StringBuilder();
            for (int count : counts) {
                keyBuilder.append(count).append('#');
            }
            String signature = keyBuilder.toString();
            groups.computeIfAbsent(signature, key -> new ArrayList<>()).add(word);
        }
        return new ArrayList<>(groups.values());
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: use the sorted characters as the grouping key.
    vector<vector<string>> groupAnagrams(vector<string>& strs) {
        unordered_map<string, vector<string>> groups;
        for (const string& word : strs) {
            string signature = word;
            sort(signature.begin(), signature.end());
            groups[signature].push_back(word);
        }

        vector<vector<string>> result;
        for (auto& entry : groups) {
            result.push_back(entry.second);
        }
        return result;
    }
};

class SolutionOptimal {
public:
    // Optimal: use the 26-letter count vector as the grouping key.
    vector<vector<string>> groupAnagrams(vector<string>& strs) {
        unordered_map<string, vector<string>> groups;
        for (const string& word : strs) {
            vector<int> counts(26, 0);
            for (char ch : word) {
                counts[ch - 'a']++;
            }
            string signature;
            for (int count : counts) {
                signature += to_string(count) + "#";
            }
            groups[signature].push_back(word);
        }

        vector<vector<string>> result;
        for (auto& entry : groups) {
            result.push_back(entry.second);
        }
        return result;
    }
};
`,
    },
  },
  {
    problemNumber: 5,
    title: 'Longest Palindromic Substring',
    slug: 'longest-palindromic-substring',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/longest-palindromic-substring',
    topics: ['Two Pointers', 'String', 'Dynamic Programming'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.3585,
    problemStatement:
      'Given a string s, return the longest palindromic substring in s.\n\nExample 1:\nInput: s = "babad"\nOutput: "bab"\nExplanation: "aba" is also a valid answer.\n\nExample 2:\nInput: s = "cbbd"\nOutput: "bb"\n\nConstraints:\n1 <= s.length <= 1000\ns consist of only digits and English letters.',
    hints: [
      'A palindrome mirrors around its center; there are 2n-1 possible centers (each character, and each gap between characters).',
      'From each center, expand outward while the characters on both sides match.',
      'Track the longest palindrome found across all centers.',
    ],
    intuition:
      'My very first instinct is brute force: check every substring to see if it is a palindrome and keep the longest. Checking a substring for palindromicity is O(length) and there are O(n^2) substrings, so that is O(n^3) - clearly too slow but a fine baseline. Thinking about what wastes time, I notice palindromes have a strong structural property: they are symmetric around a center. That suggests I should not enumerate substrings blindly but instead grow palindromes from their centers. The key realization is that every palindrome has a center, and there are only 2n-1 possible centers: each single character (for odd-length palindromes) and each gap between two adjacent characters (for even-length palindromes). From each center I expand two pointers outward as long as the characters match, which finds the longest palindrome centered there in linear time. Taking the best over all centers gives an O(n^2) algorithm with O(1) extra space, a big improvement over brute force without needing the more involved DP table or Manacher\'s algorithm.',
    walkthrough:
      'Brute force (check every substring): consider all substrings by their start and end indices; for each, verify it reads the same forward and backward by comparing characters from both ends; track the longest palindromic one. With O(n^2) substrings and O(n) verification, this is O(n^3).\n\nOptimal (expand around center): for each index center from 0 to n-1, run an expansion treating it as an odd-length center (left = center, right = center) and as an even-length center (left = center, right = center + 1). The expand helper moves left and right outward while they are in bounds and s[left] == s[right], returning the palindrome\'s bounds. Track the start and length of the longest palindrome seen, and return that substring. Each expansion is O(n) and there are O(n) centers, giving O(n^2).',
    complexityAnalysis:
      'Brute force: Time O(n^3) - O(n^2) substrings each verified in O(n); Space O(1) beyond the answer.\n\nOptimal (expand around center): Time O(n^2) because each of the 2n-1 centers expands at most O(n); Space O(1) since expansion uses only index pointers and tracks the best bounds.',
    solutions: {
      python: `class Solution:
    def longestPalindrome(self, s: str) -> str:
        # Brute force: check every substring for palindromicity.
        def is_palindrome(left, right):
            while left < right:
                if s[left] != s[right]:
                    return False
                left += 1
                right -= 1
            return True

        n = len(s)
        best = ""
        for start in range(n):
            for end in range(start, n):
                if end - start + 1 > len(best) and is_palindrome(start, end):
                    best = s[start:end + 1]
        return best


class SolutionOptimal:
    def longestPalindrome(self, s: str) -> str:
        # Optimal: expand around each possible center.
        def expand(left, right):
            while left >= 0 and right < len(s) and s[left] == s[right]:
                left -= 1
                right += 1
            return left + 1, right - 1  # bounds of the palindrome found

        start, end = 0, 0
        for center in range(len(s)):
            odd_left, odd_right = expand(center, center)
            if odd_right - odd_left > end - start:
                start, end = odd_left, odd_right
            even_left, even_right = expand(center, center + 1)
            if even_right - even_left > end - start:
                start, end = even_left, even_right

        return s[start:end + 1]
`,
      java: `class Solution {
    // Brute force: check every substring for palindromicity.
    public String longestPalindrome(String s) {
        int n = s.length();
        String best = "";
        for (int start = 0; start < n; start++) {
            for (int end = start; end < n; end++) {
                if (end - start + 1 > best.length() && isPalindrome(s, start, end)) {
                    best = s.substring(start, end + 1);
                }
            }
        }
        return best;
    }

    private boolean isPalindrome(String s, int left, int right) {
        while (left < right) {
            if (s.charAt(left) != s.charAt(right)) {
                return false;
            }
            left++;
            right--;
        }
        return true;
    }
}

class SolutionOptimal {
    // Optimal: expand around each possible center.
    private int bestStart = 0;
    private int bestEnd = 0;

    public String longestPalindrome(String s) {
        for (int center = 0; center < s.length(); center++) {
            expand(s, center, center);     // odd-length
            expand(s, center, center + 1); // even-length
        }
        return s.substring(bestStart, bestEnd + 1);
    }

    private void expand(String s, int left, int right) {
        while (left >= 0 && right < s.length() && s.charAt(left) == s.charAt(right)) {
            left--;
            right++;
        }
        int realLeft = left + 1;
        int realRight = right - 1;
        if (realRight - realLeft > bestEnd - bestStart) {
            bestStart = realLeft;
            bestEnd = realRight;
        }
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: check every substring for palindromicity.
    string longestPalindrome(string s) {
        int n = s.size();
        string best = "";
        for (int start = 0; start < n; start++) {
            for (int end = start; end < n; end++) {
                if (end - start + 1 > (int)best.size() && isPalindrome(s, start, end)) {
                    best = s.substr(start, end - start + 1);
                }
            }
        }
        return best;
    }

private:
    bool isPalindrome(const string& s, int left, int right) {
        while (left < right) {
            if (s[left] != s[right]) {
                return false;
            }
            left++;
            right--;
        }
        return true;
    }
};

class SolutionOptimal {
public:
    // Optimal: expand around each possible center.
    string longestPalindrome(string s) {
        bestStart = 0;
        bestEnd = 0;
        for (int center = 0; center < (int)s.size(); center++) {
            expand(s, center, center);     // odd-length
            expand(s, center, center + 1); // even-length
        }
        return s.substr(bestStart, bestEnd - bestStart + 1);
    }

private:
    int bestStart = 0;
    int bestEnd = 0;

    void expand(const string& s, int left, int right) {
        while (left >= 0 && right < (int)s.size() && s[left] == s[right]) {
            left--;
            right++;
        }
        int realLeft = left + 1;
        int realRight = right - 1;
        if (realRight - realLeft > bestEnd - bestStart) {
            bestStart = realLeft;
            bestEnd = realRight;
        }
    }
};
`,
    },
  },
  {
    problemNumber: 71,
    title: 'Simplify Path',
    slug: 'simplify-path',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/simplify-path',
    topics: ['String', 'Stack'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.4785,
    problemStatement:
      'You are given an absolute path for a Unix-style file system, which always begins with a slash \'/\'. Your task is to transform this absolute path into its simplified canonical path.\n\nThe rules of a Unix-style file system are as follows:\n- A single period \'.\' represents the current directory.\n- A double period \'..\' represents the previous/parent directory.\n- Multiple consecutive slashes such as \'//\' and \'///\' are treated as a single slash \'/\'.\n- Any sequence of periods that does not match the rules above should be treated as a valid directory or file name. For example, \'...\' and \'....\' are valid directory names.\n\nThe simplified canonical path should follow these rules:\n- The path must start with a single slash \'/\'.\n- Directories within the path must be separated by exactly one slash \'/\'.\n- The path must not end with a slash \'/\', unless it is the root directory.\n- The path must not have any single or double periods (\'.\' and \'..\') used to denote current or parent directories.\n\nReturn the simplified canonical path.\n\nExample 1:\nInput: path = "/home/"\nOutput: "/home"\n\nExample 2:\nInput: path = "/home//foo/"\nOutput: "/home/foo"\n\nExample 3:\nInput: path = "/a/./b/../../c/"\nOutput: "/c"\n\nConstraints:\n1 <= path.length <= 3000\npath consists of English letters, digits, period \'.\', slash \'/\' or \'_\'.\npath is a valid absolute Unix path.',
    hints: [
      'Split the path on slashes to get the sequence of components; ignore empty components and single dots.',
      'A double dot means go up one directory - remove the last valid directory you recorded.',
      'A stack naturally models entering directories (push) and going to the parent (pop).',
    ],
    intuition:
      'Walking a file path is a stack-shaped problem the moment I notice that ".." means "undo the last directory I entered." If I read the path left to right as a sequence of components separated by slashes, then entering a normal directory is a push and going up with ".." is a pop. The naive approach I might first reach for is to repeatedly do string replacements - collapse "//" to "/", remove "/./", and find "/dir/../" patterns to delete - looping until nothing changes; that works but it is fiddly and can be slow because each replacement rescans the string. The cleaner realization is to split the path on slashes once, then process each component: skip empty strings (which come from multiple or trailing slashes) and ".", pop the stack on ".." (only if the stack is non-empty, since you cannot go above root), and push anything else as a real directory name. At the end I join the stack with single slashes and prepend a slash, which automatically produces the canonical form with no trailing slash (except the root case, which falls out naturally as just "/").',
    walkthrough:
      'Brute force (iterative string replacement): repeatedly apply textual fixes - replace consecutive slashes with a single slash, remove "/./" occurrences, and locate and delete "/<dir>/../" patterns where <dir> is a normal directory - looping until the string stops changing, then strip a trailing slash. Correct but messy and re-scans repeatedly.\n\nOptimal (split and use a stack): split path on "/" into components. Initialize an empty stack. For each component: if it is "" or ".", skip it; if it is "..", pop the stack when it is non-empty (cannot go above root); otherwise push the component as a directory name. Finally, join the stack with "/" and prepend a leading "/", yielding "/" itself when the stack is empty.',
    complexityAnalysis:
      'Brute force: Time O(n^2) in the worst case because each replacement pass scans O(n) and multiple passes may be needed; Space O(n) for the working string copies.\n\nOptimal: Time O(n) - splitting and a single pass over the components, each pushed/popped at most once; Space O(n) for the stack of directory names and the split components.',
    solutions: {
      python: `class Solution:
    def simplifyPath(self, path: str) -> str:
        # Brute force: repeatedly apply textual replacements until stable.
        previous = None
        while previous != path:
            previous = path
            path = path.replace('//', '/')
        # collapse "/./" and "/dir/../" repeatedly
        components = path.split('/')
        cleaned = []
        for component in components:
            if component == '' or component == '.':
                continue
            if component == '..':
                # naive removal of the last real directory
                found = -1
                for i in range(len(cleaned) - 1, -1, -1):
                    if cleaned[i] not in ('..',):
                        found = i
                        break
                if found != -1:
                    cleaned.pop(found)
                continue
            cleaned.append(component)
        return '/' + '/'.join(cleaned)


class SolutionOptimal:
    def simplifyPath(self, path: str) -> str:
        # Optimal: split on '/', use a stack for directories.
        stack = []
        for component in path.split('/'):
            if component == '' or component == '.':
                continue
            if component == '..':
                if stack:
                    stack.pop()
            else:
                stack.append(component)
        return '/' + '/'.join(stack)
`,
      java: `class Solution {
    // Brute force: collapse slashes, then resolve dots with index scanning.
    public String simplifyPath(String path) {
        String previous = null;
        while (!path.equals(previous)) {
            previous = path;
            path = path.replace("//", "/");
        }
        String[] components = path.split("/");
        List<String> cleaned = new ArrayList<>();
        for (String component : components) {
            if (component.isEmpty() || component.equals(".")) {
                continue;
            }
            if (component.equals("..")) {
                if (!cleaned.isEmpty()) {
                    cleaned.remove(cleaned.size() - 1);
                }
                continue;
            }
            cleaned.add(component);
        }
        return "/" + String.join("/", cleaned);
    }
}

class SolutionOptimal {
    // Optimal: split on '/', use a stack for directories.
    public String simplifyPath(String path) {
        Deque<String> stack = new ArrayDeque<>();
        for (String component : path.split("/")) {
            if (component.isEmpty() || component.equals(".")) {
                continue;
            }
            if (component.equals("..")) {
                if (!stack.isEmpty()) {
                    stack.pollLast();
                }
            } else {
                stack.offerLast(component);
            }
        }
        StringBuilder result = new StringBuilder();
        for (String directory : stack) {
            result.append('/').append(directory);
        }
        return result.length() == 0 ? "/" : result.toString();
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: collapse slashes, then resolve dots with a list.
    string simplifyPath(string path) {
        string previous;
        while (path != previous) {
            previous = path;
            size_t pos;
            while ((pos = path.find("//")) != string::npos) {
                path.replace(pos, 2, "/");
            }
        }
        vector<string> cleaned;
        string component;
        stringstream stream(path);
        while (getline(stream, component, '/')) {
            if (component.empty() || component == ".") {
                continue;
            }
            if (component == "..") {
                if (!cleaned.empty()) {
                    cleaned.pop_back();
                }
                continue;
            }
            cleaned.push_back(component);
        }
        string result;
        for (const string& directory : cleaned) {
            result += "/" + directory;
        }
        return result.empty() ? "/" : result;
    }
};

class SolutionOptimal {
public:
    // Optimal: split on '/', use a stack for directories.
    string simplifyPath(string path) {
        vector<string> stack;
        string component;
        stringstream stream(path);
        while (getline(stream, component, '/')) {
            if (component.empty() || component == ".") {
                continue;
            }
            if (component == "..") {
                if (!stack.empty()) {
                    stack.pop_back();
                }
            } else {
                stack.push_back(component);
            }
        }
        string result;
        for (const string& directory : stack) {
            result += "/" + directory;
        }
        return result.empty() ? "/" : result;
    }
};
`,
    },
  },
  {
    problemNumber: 976,
    title: 'Largest Perimeter Triangle',
    slug: 'largest-perimeter-triangle',
    difficulty: 'EASY',
    link: 'https://leetcode.com/problems/largest-perimeter-triangle',
    topics: ['Array', 'Math', 'Greedy', 'Sorting'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.5737,
    problemStatement:
      'Given an integer array nums, return the largest perimeter of a triangle with a non-zero area, formed from three of these lengths. If it is impossible to form any triangle of a non-zero area, return 0.\n\nExample 1:\nInput: nums = [2,1,2]\nOutput: 5\nExplanation: You can form a triangle with three side lengths: 1, 2, and 2.\n\nExample 2:\nInput: nums = [1,2,1,10]\nOutput: 0\nExplanation:\nYou cannot use the side lengths 1, 1, and 2 to form a triangle.\nYou cannot use the side lengths 1, 1, and 10 to form a triangle.\nYou cannot use the side lengths 1, 2, and 10 to form a triangle.\nAs we cannot use any three side lengths to form a triangle of non-zero area, we return 0.\n\nConstraints:\n3 <= nums.length <= 10^4\n1 <= nums[i] <= 10^6',
    hints: [
      'Three lengths form a valid triangle when the sum of the two smaller ones strictly exceeds the largest.',
      'To maximize the perimeter, prefer the largest lengths - sort the array.',
      'After sorting, check consecutive triples from the largest end; the first valid one gives the maximum perimeter.',
    ],
    intuition:
      'The triangle inequality is the heart of this: three sides form a valid (non-degenerate) triangle exactly when the two shorter sides sum to strictly more than the longest side. The brute force is to try every triple, check the inequality, and track the maximum perimeter - O(n^3) and obviously correct. To do better, I think greedily about maximizing the perimeter: I want the three largest lengths that still satisfy the inequality. The key realization is that if I sort the array in increasing order, then for any triple of consecutive sorted values, only the largest matters for the inequality check, because the two largest possible "shorter" sides for a given longest side are the two values immediately below it. So I scan from the largest end, looking at each consecutive triple (nums[i-2], nums[i-1], nums[i]); the first one where the two smaller sum to more than the largest is automatically the maximum-perimeter valid triangle, since the values are as large as possible. If no consecutive triple works, no triple works at all, so I return 0.',
    walkthrough:
      'Brute force (all triples): iterate over all index triples i < j < k, treat the three values as candidate sides, sort the three to find the largest, check whether the two smaller strictly exceed the largest, and if so update the maximum perimeter. O(n^3).\n\nOptimal (sort and check consecutive triples from the top): sort nums ascending. Iterate i from the last index down to 2, examining the triple nums[i-2], nums[i-1], nums[i] where nums[i] is the largest. If nums[i-2] + nums[i-1] > nums[i], these three form a valid triangle, and because we are scanning from the largest values down, this is the maximum perimeter - return their sum. If no triple satisfies the inequality, return 0.',
    complexityAnalysis:
      'Brute force: Time O(n^3) for examining all triples; Space O(1) beyond the input.\n\nOptimal: Time O(n log n) dominated by the sort, plus an O(n) scan of consecutive triples; Space O(1) extra (or O(log n) to O(n) for the sort depending on implementation).',
    solutions: {
      python: `class Solution:
    def largestPerimeter(self, nums):
        # Brute force: try every triple and check the triangle inequality.
        n = len(nums)
        best = 0
        for i in range(n):
            for j in range(i + 1, n):
                for k in range(j + 1, n):
                    sides = sorted([nums[i], nums[j], nums[k]])
                    if sides[0] + sides[1] > sides[2]:
                        best = max(best, sides[0] + sides[1] + sides[2])
        return best


class SolutionOptimal:
    def largestPerimeter(self, nums):
        # Optimal: sort, then check consecutive triples from the largest down.
        nums.sort()
        for i in range(len(nums) - 1, 1, -1):
            if nums[i - 2] + nums[i - 1] > nums[i]:
                return nums[i - 2] + nums[i - 1] + nums[i]
        return 0
`,
      java: `class Solution {
    // Brute force: try every triple and check the triangle inequality.
    public int largestPerimeter(int[] nums) {
        int n = nums.length;
        int best = 0;
        for (int i = 0; i < n; i++) {
            for (int j = i + 1; j < n; j++) {
                for (int k = j + 1; k < n; k++) {
                    int[] sides = {nums[i], nums[j], nums[k]};
                    Arrays.sort(sides);
                    if (sides[0] + sides[1] > sides[2]) {
                        best = Math.max(best, sides[0] + sides[1] + sides[2]);
                    }
                }
            }
        }
        return best;
    }
}

class SolutionOptimal {
    // Optimal: sort, then check consecutive triples from the largest down.
    public int largestPerimeter(int[] nums) {
        Arrays.sort(nums);
        for (int i = nums.length - 1; i >= 2; i--) {
            if (nums[i - 2] + nums[i - 1] > nums[i]) {
                return nums[i - 2] + nums[i - 1] + nums[i];
            }
        }
        return 0;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: try every triple and check the triangle inequality.
    int largestPerimeter(vector<int>& nums) {
        int n = nums.size();
        int best = 0;
        for (int i = 0; i < n; i++) {
            for (int j = i + 1; j < n; j++) {
                for (int k = j + 1; k < n; k++) {
                    vector<int> sides = {nums[i], nums[j], nums[k]};
                    sort(sides.begin(), sides.end());
                    if (sides[0] + sides[1] > sides[2]) {
                        best = max(best, sides[0] + sides[1] + sides[2]);
                    }
                }
            }
        }
        return best;
    }
};

class SolutionOptimal {
public:
    // Optimal: sort, then check consecutive triples from the largest down.
    int largestPerimeter(vector<int>& nums) {
        sort(nums.begin(), nums.end());
        for (int i = nums.size() - 1; i >= 2; i--) {
            if (nums[i - 2] + nums[i - 1] > nums[i]) {
                return nums[i - 2] + nums[i - 1] + nums[i];
            }
        }
        return 0;
    }
};
`,
    },
  },
  {
    problemNumber: 268,
    title: 'Missing Number',
    slug: 'missing-number',
    difficulty: 'EASY',
    link: 'https://leetcode.com/problems/missing-number',
    topics: ['Array', 'Hash Table', 'Math', 'Binary Search', 'Bit Manipulation', 'Sorting'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.7007,
    problemStatement:
      'Given an array nums containing n distinct numbers in the range [0, n], return the only number in the range that is missing from the array.\n\nExample 1:\nInput: nums = [3,0,1]\nOutput: 2\nExplanation: n = 3 since there are 3 numbers, so all numbers are in the range [0,3]. 2 is the missing number in the range since it does not appear in nums.\n\nExample 2:\nInput: nums = [0,1]\nOutput: 2\nExplanation: n = 2 since there are 2 numbers, so all numbers are in the range [0,2]. 2 is the missing number in the range since it does not appear in nums.\n\nExample 3:\nInput: nums = [9,6,4,2,3,5,7,0,1]\nOutput: 8\nExplanation: n = 9 since there are 9 numbers, so all numbers are in the range [0,9]. 8 is the missing number in the range since it does not appear in nums.\n\nConstraints:\nn == nums.length\n1 <= n <= 10^4\n0 <= nums[i] <= n\nAll the numbers of nums are unique.\n\nFollow up: Could you implement a solution using only O(1) extra space complexity and O(n) runtime complexity?',
    hints: [
      'The full set 0..n has a known sum; the array is that set minus one number.',
      'Subtract the actual array sum from the expected sum of 0..n to get the missing number.',
      'Alternatively, XOR all indices 0..n with all array values - matching pairs cancel, leaving the missing number.',
    ],
    intuition:
      'The numbers are supposed to be exactly 0 through n with one missing, so the structure is very rigid and I can exploit arithmetic instead of searching. The naive idea is to throw the array into a hash set and then check each value from 0 to n to find the one not present - O(n) time but O(n) extra space. The cleaner realization is that I know what the complete set should sum to: 0 + 1 + ... + n, which is n*(n+1)/2 by the Gauss formula. If I subtract the actual sum of the array from that expected sum, the difference is precisely the missing number, because every present number cancels out. That is O(n) time and O(1) space. An even slicker alternative avoids any worry about integer overflow: XOR all the indices 0..n together with all the array values; every number that appears in both the index range and the array cancels itself out (since x XOR x = 0), and the one missing number is left standing. Both achieve the O(1) space, O(n) time the follow-up asks for.',
    walkthrough:
      'Brute force (hash set): insert every value of nums into a set, then loop candidate from 0 to n and return the first candidate not in the set. O(n) time but O(n) extra space.\n\nOptimal (sum formula): compute expected_sum = n * (n + 1) / 2 where n is the array length, then subtract the actual sum of the array. The result is the missing number, since the present numbers cancel against their counterparts in the expected total. (An equivalent XOR approach folds index i and nums[i] into a running XOR plus a final XOR with n, leaving the missing value and sidestepping overflow.)',
    complexityAnalysis:
      'Brute force: Time O(n) to build the set and scan; Space O(n) for the set - fails the follow-up space goal.\n\nOptimal: Time O(n) to sum the array once; Space O(1) since only the expected and actual sums are tracked (the XOR variant is likewise O(n) time and O(1) space and avoids overflow concerns).',
    solutions: {
      python: `class Solution:
    def missingNumber(self, nums):
        # Brute force: hash set membership check over 0..n.
        present = set(nums)
        for candidate in range(len(nums) + 1):
            if candidate not in present:
                return candidate
        return -1  # unreachable for valid input


class SolutionOptimal:
    def missingNumber(self, nums):
        # Optimal: expected sum of 0..n minus the actual sum.
        n = len(nums)
        expected_sum = n * (n + 1) // 2
        actual_sum = sum(nums)
        return expected_sum - actual_sum
`,
      java: `class Solution {
    // Brute force: hash set membership check over 0..n.
    public int missingNumber(int[] nums) {
        Set<Integer> present = new HashSet<>();
        for (int num : nums) {
            present.add(num);
        }
        for (int candidate = 0; candidate <= nums.length; candidate++) {
            if (!present.contains(candidate)) {
                return candidate;
            }
        }
        return -1; // unreachable for valid input
    }
}

class SolutionOptimal {
    // Optimal: expected sum of 0..n minus the actual sum.
    public int missingNumber(int[] nums) {
        int n = nums.length;
        int expectedSum = n * (n + 1) / 2;
        int actualSum = 0;
        for (int num : nums) {
            actualSum += num;
        }
        return expectedSum - actualSum;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: hash set membership check over 0..n.
    int missingNumber(vector<int>& nums) {
        unordered_set<int> present(nums.begin(), nums.end());
        for (int candidate = 0; candidate <= (int)nums.size(); candidate++) {
            if (present.find(candidate) == present.end()) {
                return candidate;
            }
        }
        return -1; // unreachable for valid input
    }
};

class SolutionOptimal {
public:
    // Optimal: expected sum of 0..n minus the actual sum.
    int missingNumber(vector<int>& nums) {
        int n = nums.size();
        int expectedSum = n * (n + 1) / 2;
        int actualSum = 0;
        for (int num : nums) {
            actualSum += num;
        }
        return expectedSum - actualSum;
    }
};
`,
    },
  },
  {
    problemNumber: 105,
    title: 'Construct Binary Tree from Preorder and Inorder Traversal',
    slug: 'construct-binary-tree-from-preorder-and-inorder-traversal',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/construct-binary-tree-from-preorder-and-inorder-traversal',
    topics: ['Array', 'Hash Table', 'Divide and Conquer', 'Tree', 'Binary Tree'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.6684,
    problemStatement:
      'Given two integer arrays preorder and inorder where preorder is the preorder traversal of a binary tree and inorder is the inorder traversal of the same tree, construct and return the binary tree.\n\nExample 1:\nInput: preorder = [3,9,20,15,7], inorder = [9,3,15,20,7]\nOutput: [3,9,20,null,null,15,7]\n\nExample 2:\nInput: preorder = [-1], inorder = [-1]\nOutput: [-1]\n\nConstraints:\n1 <= preorder.length <= 3000\ninorder.length == preorder.length\n-3000 <= preorder[i], inorder[i] <= 3000\npreorder and inorder consist of unique values.\nEach value of inorder also appears in preorder.\npreorder is guaranteed to be the preorder traversal of the tree.\ninorder is guaranteed to be the inorder traversal of the tree.',
    hints: [
      'The first element of a preorder traversal is always the root of the (sub)tree.',
      'Finding the root inside the inorder array splits it into the left subtree (to its left) and right subtree (to its right).',
      'Recurse on the corresponding slices of preorder and inorder; a hash map of value to inorder index makes the split O(1).',
    ],
    intuition:
      'The two traversals encode complementary information: preorder tells me the root first, and inorder tells me, given a root, which values are in its left subtree versus its right subtree. The first element of preorder is the overall root. If I find that root\'s position in inorder, everything to the left of it belongs to the left subtree and everything to the right belongs to the right subtree. That immediately suggests a recursive divide-and-conquer: take the next preorder element as the current root, locate it in inorder to learn the sizes of the two sides, then recursively build the left subtree from the matching slices and the right subtree from the rest. My naive first version literally searches inorder linearly for each root, which is O(n) per node and O(n^2) overall. The key optimization is to precompute a hash map from value to its index in inorder, turning each lookup into O(1). I also walk preorder with a single advancing pointer so that consuming roots in preorder order is automatic, which makes the whole construction a clean O(n).',
    walkthrough:
      'Brute force (linear search for root each time): recursive function build(preorder_segment, inorder_segment). The root is the first element of the preorder segment; scan the inorder segment linearly to find its index, which splits inorder into left and right parts; split the preorder segment by the left part\'s size; recurse to build left and right children. The linear search per node makes it O(n^2), and slicing arrays adds overhead.\n\nOptimal (index map + preorder pointer): build a hash map index_in_inorder from each value to its inorder index. Maintain a single preorder_position pointer starting at 0. The recursive helper takes the current inorder range [left, right]. If left > right return null. Take root_value = preorder[preorder_position] and advance the pointer; create the root node. Look up the root in index_in_inorder to get mid. Recurse on [left, mid - 1] for the left child, then [mid + 1, right] for the right child (this order matches preorder consuming the root, then all of the left subtree, then the right). Return the root.',
    complexityAnalysis:
      'Brute force: Time O(n^2) because each of n nodes does an O(n) linear search in inorder (plus array slicing); Space O(n) for the recursion and the array slices.\n\nOptimal: Time O(n) since the index map makes each root lookup O(1) and every node is created once; Space O(n) for the index map plus O(h) recursion stack where h is the tree height (up to O(n) when skewed).',
    solutions: {
      python: `# Definition for a binary tree node.
# class TreeNode:
#     def __init__(self, val=0, left=None, right=None):
#         self.val = val
#         self.left = left
#         self.right = right


class Solution:
    def buildTree(self, preorder, inorder):
        # Brute force: linear search for the root in inorder each call.
        if not preorder:
            return None
        root_value = preorder[0]
        root = TreeNode(root_value)
        mid = inorder.index(root_value)  # O(n) search
        root.left = self.buildTree(preorder[1:mid + 1], inorder[:mid])
        root.right = self.buildTree(preorder[mid + 1:], inorder[mid + 1:])
        return root


class SolutionOptimal:
    def buildTree(self, preorder, inorder):
        # Optimal: index map for O(1) root lookup + a preorder pointer.
        index_in_inorder = {value: i for i, value in enumerate(inorder)}
        self.preorder_position = 0

        def build(left, right):
            if left > right:
                return None
            root_value = preorder[self.preorder_position]
            self.preorder_position += 1
            root = TreeNode(root_value)
            mid = index_in_inorder[root_value]
            root.left = build(left, mid - 1)
            root.right = build(mid + 1, right)
            return root

        return build(0, len(inorder) - 1)
`,
      java: `/**
 * Definition for a binary tree node.
 * public class TreeNode {
 *     int val;
 *     TreeNode left;
 *     TreeNode right;
 *     TreeNode(int x) { val = x; }
 * }
 */
class Solution {
    // Brute force: linear search for the root in inorder each call.
    public TreeNode buildTree(int[] preorder, int[] inorder) {
        return build(preorder, 0, preorder.length - 1, inorder, 0, inorder.length - 1);
    }

    private TreeNode build(int[] preorder, int preStart, int preEnd,
                           int[] inorder, int inStart, int inEnd) {
        if (preStart > preEnd) {
            return null;
        }
        int rootValue = preorder[preStart];
        TreeNode root = new TreeNode(rootValue);
        int mid = inStart;
        while (inorder[mid] != rootValue) { // O(n) search
            mid++;
        }
        int leftSize = mid - inStart;
        root.left = build(preorder, preStart + 1, preStart + leftSize,
                          inorder, inStart, mid - 1);
        root.right = build(preorder, preStart + leftSize + 1, preEnd,
                           inorder, mid + 1, inEnd);
        return root;
    }
}

class SolutionOptimal {
    // Optimal: index map for O(1) root lookup + a preorder pointer.
    private int preorderPosition = 0;
    private Map<Integer, Integer> indexInInorder = new HashMap<>();

    public TreeNode buildTree(int[] preorder, int[] inorder) {
        for (int i = 0; i < inorder.length; i++) {
            indexInInorder.put(inorder[i], i);
        }
        return build(preorder, 0, inorder.length - 1);
    }

    private TreeNode build(int[] preorder, int left, int right) {
        if (left > right) {
            return null;
        }
        int rootValue = preorder[preorderPosition++];
        TreeNode root = new TreeNode(rootValue);
        int mid = indexInInorder.get(rootValue);
        root.left = build(preorder, left, mid - 1);
        root.right = build(preorder, mid + 1, right);
        return root;
    }
}
`,
      cpp: `/**
 * Definition for a binary tree node.
 * struct TreeNode {
 *     int val;
 *     TreeNode *left;
 *     TreeNode *right;
 *     TreeNode(int x) : val(x), left(nullptr), right(nullptr) {}
 * };
 */
class Solution {
public:
    // Brute force: linear search for the root in inorder each call.
    TreeNode* buildTree(vector<int>& preorder, vector<int>& inorder) {
        return build(preorder, 0, preorder.size() - 1,
                     inorder, 0, inorder.size() - 1);
    }

private:
    TreeNode* build(vector<int>& preorder, int preStart, int preEnd,
                    vector<int>& inorder, int inStart, int inEnd) {
        if (preStart > preEnd) {
            return nullptr;
        }
        int rootValue = preorder[preStart];
        TreeNode* root = new TreeNode(rootValue);
        int mid = inStart;
        while (inorder[mid] != rootValue) { // O(n) search
            mid++;
        }
        int leftSize = mid - inStart;
        root->left = build(preorder, preStart + 1, preStart + leftSize,
                           inorder, inStart, mid - 1);
        root->right = build(preorder, preStart + leftSize + 1, preEnd,
                            inorder, mid + 1, inEnd);
        return root;
    }
};

class SolutionOptimal {
public:
    // Optimal: index map for O(1) root lookup + a preorder pointer.
    TreeNode* buildTree(vector<int>& preorder, vector<int>& inorder) {
        for (int i = 0; i < (int)inorder.size(); i++) {
            indexInInorder[inorder[i]] = i;
        }
        preorderPosition = 0;
        this->preorder = &preorder;
        return build(0, inorder.size() - 1);
    }

private:
    int preorderPosition = 0;
    vector<int>* preorder;
    unordered_map<int, int> indexInInorder;

    TreeNode* build(int left, int right) {
        if (left > right) {
            return nullptr;
        }
        int rootValue = (*preorder)[preorderPosition++];
        TreeNode* root = new TreeNode(rootValue);
        int mid = indexInInorder[rootValue];
        root->left = build(left, mid - 1);
        root->right = build(mid + 1, right);
        return root;
    }
};
`,
    },
  },
  {
    problemNumber: 392,
    title: 'Is Subsequence',
    slug: 'is-subsequence',
    difficulty: 'EASY',
    link: 'https://leetcode.com/problems/is-subsequence',
    topics: ['Two Pointers', 'String', 'Dynamic Programming'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.4838,
    problemStatement:
      'Given two strings s and t, return true if s is a subsequence of t, or false otherwise.\n\nA subsequence of a string is a new string that is formed from the original string by deleting some (can be none) of the characters without disturbing the relative positions of the remaining characters. (i.e., "ace" is a subsequence of "abcde" while "aec" is not).\n\nExample 1:\nInput: s = "abc", t = "ahbgdc"\nOutput: true\n\nExample 2:\nInput: s = "axc", t = "ahbgdc"\nOutput: false\n\nConstraints:\n0 <= s.length <= 100\n0 <= t.length <= 10^4\ns and t consist only of lowercase English letters.\n\nFollow up: Suppose there are lots of incoming s, say s1, s2, ..., sk where k >= 10^9, and you want to check one by one to see if t has its subsequence. In this scenario, how would you change your code?',
    hints: [
      'Scan t left to right, trying to match the characters of s in order.',
      'Keep a pointer into s; advance it each time the current character of t matches the next needed character of s.',
      's is a subsequence exactly when that pointer reaches the end of s.',
    ],
    intuition:
      'A subsequence just means I can find all of s\'s characters inside t in the same left-to-right order, with arbitrary gaps allowed. The most natural way to verify this is to greedily match: I walk through t once, and I keep a pointer at the next character of s that I still need to find. Whenever the current character of t equals that needed character, I advance the s pointer because I have matched it; otherwise I just keep moving through t. If the s pointer reaches the end, every character of s was matched in order, so it is a subsequence. The greedy choice of matching each s character at its earliest opportunity in t is provably safe - matching earlier never hurts because it leaves the most of t available for the remaining characters. My more "brute force" framing of the same idea is a recursive matcher that, at each step, either consumes a matched character from both strings or skips a character of t; the two-pointer loop is just the clean iterative version of that, and both are linear in the length of t.',
    walkthrough:
      'Brute force (recursion over indices): a recursive function match(i, j) checks whether s[i:] is a subsequence of t[j:]. If i reaches the end of s, return true. If j reaches the end of t, return false. If s[i] == t[j], recurse on (i + 1, j + 1); otherwise recurse on (i, j + 1) to skip the current character of t. This expresses the same matching but with recursion-call overhead.\n\nOptimal (two pointers): keep s_index at 0. Loop a pointer over each character of t; whenever s_index is still within s and t\'s current character equals s[s_index], increment s_index. After scanning t, return whether s_index reached len(s), meaning all of s was matched in order.',
    complexityAnalysis:
      'Brute force (recursion): Time O(len(t)) since j advances every call and the recursion depth is bounded by the length of t; Space O(len(t)) for the recursion stack.\n\nOptimal: Time O(len(t)) for the single scan of t; Space O(1) since only the two index pointers are kept. (For the follow-up with many queries, preprocessing t into per-character sorted index lists lets each query run in O(len(s) log len(t)).)',
    solutions: {
      python: `class Solution:
    def isSubsequence(self, s: str, t: str) -> bool:
        # Brute force: recursion that matches or skips a character of t.
        def match(i, j):
            if i == len(s):
                return True
            if j == len(t):
                return False
            if s[i] == t[j]:
                return match(i + 1, j + 1)
            return match(i, j + 1)

        return match(0, 0)


class SolutionOptimal:
    def isSubsequence(self, s: str, t: str) -> bool:
        # Optimal: two pointers, greedily match s within t.
        s_index = 0
        for ch in t:
            if s_index < len(s) and ch == s[s_index]:
                s_index += 1
        return s_index == len(s)
`,
      java: `class Solution {
    // Brute force: recursion that matches or skips a character of t.
    public boolean isSubsequence(String s, String t) {
        return match(s, t, 0, 0);
    }

    private boolean match(String s, String t, int i, int j) {
        if (i == s.length()) {
            return true;
        }
        if (j == t.length()) {
            return false;
        }
        if (s.charAt(i) == t.charAt(j)) {
            return match(s, t, i + 1, j + 1);
        }
        return match(s, t, i, j + 1);
    }
}

class SolutionOptimal {
    // Optimal: two pointers, greedily match s within t.
    public boolean isSubsequence(String s, String t) {
        int sIndex = 0;
        for (int j = 0; j < t.length(); j++) {
            if (sIndex < s.length() && t.charAt(j) == s.charAt(sIndex)) {
                sIndex++;
            }
        }
        return sIndex == s.length();
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: recursion that matches or skips a character of t.
    bool isSubsequence(string s, string t) {
        return match(s, t, 0, 0);
    }

private:
    bool match(const string& s, const string& t, int i, int j) {
        if (i == (int)s.size()) {
            return true;
        }
        if (j == (int)t.size()) {
            return false;
        }
        if (s[i] == t[j]) {
            return match(s, t, i + 1, j + 1);
        }
        return match(s, t, i, j + 1);
    }
};

class SolutionOptimal {
public:
    // Optimal: two pointers, greedily match s within t.
    bool isSubsequence(string s, string t) {
        int sIndex = 0;
        for (int j = 0; j < (int)t.size(); j++) {
            if (sIndex < (int)s.size() && t[j] == s[sIndex]) {
                sIndex++;
            }
        }
        return sIndex == (int)s.size();
    }
};
`,
    },
  },
  {
    problemNumber: 40,
    title: 'Combination Sum II',
    slug: 'combination-sum-ii',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/combination-sum-ii',
    topics: ['Array', 'Backtracking'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.5767,
    problemStatement:
      'Given a collection of candidate numbers (candidates) and a target number (target), find all unique combinations in candidates where the candidate numbers sum to target.\n\nEach number in candidates may only be used once in the combination.\n\nNote: The solution set must not contain duplicate combinations.\n\nExample 1:\nInput: candidates = [10,1,2,7,6,1,5], target = 8\nOutput: [[1,1,6],[1,2,5],[1,7],[2,6]]\n\nExample 2:\nInput: candidates = [2,5,2,1,2], target = 5\nOutput: [[1,2,2],[5]]\n\nConstraints:\n1 <= candidates.length <= 100\n1 <= candidates[i] <= 50\n1 <= target <= 30',
    hints: [
      'This is a backtracking search: at each step choose to include the next candidate or move past it.',
      'Each number can be used once, so always advance to the next index after picking one.',
      'Sort the candidates so duplicates are adjacent, then skip a duplicate at the same recursion depth to avoid producing duplicate combinations.',
    ],
    intuition:
      'This is a classic "find all subsets that hit a target sum" problem, so backtracking is the natural tool: I build a combination element by element, and at each candidate I decide whether to include it. Two wrinkles make it specifically Combination Sum II. First, each number may be used at most once, so after choosing the candidate at index i, my recursion must continue from i + 1, not i. Second, the input can contain duplicate values, and I must not emit the same combination twice. The naive way to handle duplicates is to collect all combinations into a set to dedupe, which is wasteful. The cleaner realization is to sort the candidates so equal values sit next to each other, and then at any given recursion level, once I have tried a particular value, I skip over any further identical values at that same level - because choosing the second identical candidate as the "first pick at this level" would just regenerate combinations already produced by the first. I also prune: since the array is sorted, once the current candidate exceeds the remaining target, I can stop exploring further candidates at that level.',
    walkthrough:
      'Brute force (generate all subsets, filter, dedupe): recursively enumerate every subset (include or exclude each index, advancing the index so each element is used once), and whenever a subset sums to target, add its sorted form to a set to remove duplicates. Convert the set to a list at the end. Correct but explores all 2^n subsets and relies on a dedup set.\n\nOptimal (sorted backtracking with duplicate skipping): sort candidates. Run backtrack(start, remaining, path): if remaining == 0, record a copy of path as a valid combination and return. Iterate i from start; if i > start and candidates[i] == candidates[i - 1], skip it to avoid duplicate combinations at this level. If candidates[i] > remaining, break (sorted, so nothing further fits). Otherwise append candidates[i], recurse with backtrack(i + 1, remaining - candidates[i], path), then pop to backtrack. This produces each unique combination exactly once.',
    complexityAnalysis:
      'Brute force: Time O(2^n * n) - it generates all 2^n subsets and spends O(n) per subset to sum and copy into the dedup set; Space O(2^n * n) for the stored subsets in the worst case.\n\nOptimal: Time O(2^n * n) in the worst case (the number of valid combinations can be exponential and each costs O(n) to copy), but duplicate skipping and the sorted-order pruning cut the explored search space substantially in practice; Space O(n) for the recursion depth and the current path, excluding the output.',
    solutions: {
      python: `class Solution:
    def combinationSum2(self, candidates, target):
        # Brute force: enumerate all subsets, keep those summing to target,
        # dedupe with a set of sorted tuples.
        results = set()
        n = len(candidates)

        def enumerate_subsets(start, current_sum, path):
            if current_sum == target:
                results.add(tuple(sorted(path)))
                return
            if current_sum > target:
                return
            for i in range(start, n):
                path.append(candidates[i])
                enumerate_subsets(i + 1, current_sum + candidates[i], path)
                path.pop()

        enumerate_subsets(0, 0, [])
        return [list(combo) for combo in results]


class SolutionOptimal:
    def combinationSum2(self, candidates, target):
        # Optimal: sorted backtracking, skipping duplicates per level.
        candidates.sort()
        results = []

        def backtrack(start, remaining, path):
            if remaining == 0:
                results.append(path[:])
                return
            for i in range(start, len(candidates)):
                if i > start and candidates[i] == candidates[i - 1]:
                    continue  # skip duplicate at this level
                if candidates[i] > remaining:
                    break  # sorted: nothing further fits
                path.append(candidates[i])
                backtrack(i + 1, remaining - candidates[i], path)
                path.pop()

        backtrack(0, target, [])
        return results
`,
      java: `class Solution {
    // Brute force: enumerate all subsets, dedupe with a set of sorted lists.
    public List<List<Integer>> combinationSum2(int[] candidates, int target) {
        Set<List<Integer>> results = new HashSet<>();
        enumerate(candidates, 0, 0, target, new ArrayList<>(), results);
        return new ArrayList<>(results);
    }

    private void enumerate(int[] candidates, int start, int currentSum, int target,
                           List<Integer> path, Set<List<Integer>> results) {
        if (currentSum == target) {
            List<Integer> sorted = new ArrayList<>(path);
            Collections.sort(sorted);
            results.add(sorted);
            return;
        }
        if (currentSum > target) {
            return;
        }
        for (int i = start; i < candidates.length; i++) {
            path.add(candidates[i]);
            enumerate(candidates, i + 1, currentSum + candidates[i], target, path, results);
            path.remove(path.size() - 1);
        }
    }
}

class SolutionOptimal {
    // Optimal: sorted backtracking, skipping duplicates per level.
    public List<List<Integer>> combinationSum2(int[] candidates, int target) {
        Arrays.sort(candidates);
        List<List<Integer>> results = new ArrayList<>();
        backtrack(candidates, 0, target, new ArrayList<>(), results);
        return results;
    }

    private void backtrack(int[] candidates, int start, int remaining,
                           List<Integer> path, List<List<Integer>> results) {
        if (remaining == 0) {
            results.add(new ArrayList<>(path));
            return;
        }
        for (int i = start; i < candidates.length; i++) {
            if (i > start && candidates[i] == candidates[i - 1]) {
                continue; // skip duplicate at this level
            }
            if (candidates[i] > remaining) {
                break; // sorted: nothing further fits
            }
            path.add(candidates[i]);
            backtrack(candidates, i + 1, remaining - candidates[i], path, results);
            path.remove(path.size() - 1);
        }
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: enumerate all subsets, dedupe with a set of sorted lists.
    vector<vector<int>> combinationSum2(vector<int>& candidates, int target) {
        set<vector<int>> results;
        vector<int> path;
        enumerate(candidates, 0, 0, target, path, results);
        return vector<vector<int>>(results.begin(), results.end());
    }

private:
    void enumerate(vector<int>& candidates, int start, int currentSum, int target,
                   vector<int>& path, set<vector<int>>& results) {
        if (currentSum == target) {
            vector<int> sorted = path;
            sort(sorted.begin(), sorted.end());
            results.insert(sorted);
            return;
        }
        if (currentSum > target) {
            return;
        }
        for (int i = start; i < (int)candidates.size(); i++) {
            path.push_back(candidates[i]);
            enumerate(candidates, i + 1, currentSum + candidates[i], target, path, results);
            path.pop_back();
        }
    }
};

class SolutionOptimal {
public:
    // Optimal: sorted backtracking, skipping duplicates per level.
    vector<vector<int>> combinationSum2(vector<int>& candidates, int target) {
        sort(candidates.begin(), candidates.end());
        vector<vector<int>> results;
        vector<int> path;
        backtrack(candidates, 0, target, path, results);
        return results;
    }

private:
    void backtrack(vector<int>& candidates, int start, int remaining,
                   vector<int>& path, vector<vector<int>>& results) {
        if (remaining == 0) {
            results.push_back(path);
            return;
        }
        for (int i = start; i < (int)candidates.size(); i++) {
            if (i > start && candidates[i] == candidates[i - 1]) {
                continue; // skip duplicate at this level
            }
            if (candidates[i] > remaining) {
                break; // sorted: nothing further fits
            }
            path.push_back(candidates[i]);
            backtrack(candidates, i + 1, remaining - candidates[i], path, results);
            path.pop_back();
        }
    }
};
`,
    },
  },
  {
    problemNumber: 153,
    title: 'Find Minimum in Rotated Sorted Array',
    slug: 'find-minimum-in-rotated-sorted-array',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/find-minimum-in-rotated-sorted-array',
    topics: ['Array', 'Binary Search'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.5265,
    problemStatement:
      'Suppose an array of length n sorted in ascending order is rotated between 1 and n times. For example, the array nums = [0,1,2,4,5,6,7] might become:\n[4,5,6,7,0,1,2] if it was rotated 4 times.\n[0,1,2,4,5,6,7] if it was rotated 7 times.\n\nNotice that rotating an array [a[0], a[1], a[2], ..., a[n-1]] 1 time results in the array [a[n-1], a[0], a[1], a[2], ..., a[n-2]].\n\nGiven the sorted rotated array nums of unique elements, return the minimum element of this array.\n\nYou must write an algorithm that runs in O(log n) time.\n\nExample 1:\nInput: nums = [3,4,5,1,2]\nOutput: 1\nExplanation: The original array was [1,2,3,4,5] rotated 3 times.\n\nExample 2:\nInput: nums = [4,5,6,7,0,1,2]\nOutput: 0\nExplanation: The original array was [0,1,2,4,5,6,7] and it was rotated 4 times.\n\nExample 3:\nInput: nums = [11,13,15,17]\nOutput: 11\n\nConstraints:\nn == nums.length\n1 <= n <= 5000\n-5000 <= nums[i] <= 5000\nAll the integers of nums are unique.\nnums is rotated between 1 and n times.',
    hints: [
      'The minimum is the single "pivot" point where the order drops from a larger value to a smaller one.',
      'Compare the middle element with the rightmost element to decide which half contains the pivot.',
      'If nums[mid] > nums[right], the minimum is to the right of mid; otherwise it is at mid or to its left.',
    ],
    intuition:
      'The array is sorted then rotated, which means it consists of two ascending runs, and the minimum sits exactly at the "break" where a larger value is immediately followed by a smaller one. The trivial brute force is to scan the whole array and take the minimum - O(n), correct, but the problem demands O(log n), which screams binary search. The challenge is that the array is not fully sorted, so I cannot binary search for a target directly; instead I binary search for the pivot. The key realization is that comparing the middle element to the rightmost element tells me which side the pivot is on. If nums[mid] > nums[right], then the rotation point (and thus the minimum) must lie strictly to the right of mid, because a properly sorted suffix would have its largest at the right, not be exceeded by the middle. Otherwise, nums[mid] <= nums[right] means the right half is properly ordered, so the minimum is at mid or to its left, and I keep mid as a candidate. I narrow until left meets right, which lands on the minimum.',
    walkthrough:
      'Brute force (linear scan): walk the array tracking the smallest value seen and return it. O(n), ignoring the structure.\n\nOptimal (binary search for the pivot): set left = 0, right = n - 1. While left < right, compute mid = (left + right) / 2. If nums[mid] > nums[right], the minimum lies to the right of mid, so set left = mid + 1. Otherwise nums[mid] <= nums[right], meaning the right portion is sorted and the minimum is at mid or earlier, so set right = mid (keeping mid as a candidate). When left == right, that index holds the minimum, so return nums[left]. Comparing against the right end (rather than the left) avoids ambiguity when the searched range is already sorted.',
    complexityAnalysis:
      'Brute force: Time O(n) for the full scan; Space O(1).\n\nOptimal: Time O(log n) because each comparison halves the search range; Space O(1) for the two pointers.',
    solutions: {
      python: `class Solution:
    def findMin(self, nums):
        # Brute force: linear scan for the minimum.
        smallest = nums[0]
        for num in nums:
            if num < smallest:
                smallest = num
        return smallest


class SolutionOptimal:
    def findMin(self, nums):
        # Optimal: binary search for the rotation pivot.
        left = 0
        right = len(nums) - 1
        while left < right:
            mid = (left + right) // 2
            if nums[mid] > nums[right]:
                # minimum is strictly to the right of mid
                left = mid + 1
            else:
                # minimum is at mid or to its left
                right = mid
        return nums[left]
`,
      java: `class Solution {
    // Brute force: linear scan for the minimum.
    public int findMin(int[] nums) {
        int smallest = nums[0];
        for (int num : nums) {
            if (num < smallest) {
                smallest = num;
            }
        }
        return smallest;
    }
}

class SolutionOptimal {
    // Optimal: binary search for the rotation pivot.
    public int findMin(int[] nums) {
        int left = 0;
        int right = nums.length - 1;
        while (left < right) {
            int mid = (left + right) / 2;
            if (nums[mid] > nums[right]) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }
        return nums[left];
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: linear scan for the minimum.
    int findMin(vector<int>& nums) {
        int smallest = nums[0];
        for (int num : nums) {
            if (num < smallest) {
                smallest = num;
            }
        }
        return smallest;
    }
};

class SolutionOptimal {
public:
    // Optimal: binary search for the rotation pivot.
    int findMin(vector<int>& nums) {
        int left = 0;
        int right = nums.size() - 1;
        while (left < right) {
            int mid = (left + right) / 2;
            if (nums[mid] > nums[right]) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }
        return nums[left];
    }
};
`,
    },
  },
  {
    problemNumber: 1188,
    title: 'Design Bounded Blocking Queue',
    slug: 'design-bounded-blocking-queue',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/design-bounded-blocking-queue',
    topics: ['Concurrency'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.7299,
    problemStatement:
      'Implement a thread-safe bounded blocking queue that has the following methods:\n- BoundedBlockingQueue(int capacity) The constructor initializes the queue with a maximum capacity.\n- void enqueue(int element) Adds an element to the front of the queue. If the queue is full, the calling thread is blocked until the queue is no longer full.\n- int dequeue() Returns the element at the rear of the queue and removes it. If the queue is empty, the calling thread is blocked until the queue is no longer empty.\n- int size() Returns the number of elements currently in the queue.\n\nYour implementation will be tested using multiple threads at the same time. Each thread will either be a producer thread that only makes calls to the enqueue method or a consumer thread that only makes calls to the dequeue method. The size method will be called after every test case.\n\nPlease do not use built-in implementations of bounded blocking queue as this will not be accepted in an interview.\n\nExample 1:\nInput:\n1\n1\n["BoundedBlockingQueue","enqueue","dequeue","dequeue","enqueue","enqueue","enqueue","enqueue","dequeue"]\n[[2],[1],[],[],[0],[2],[3],[4],[]]\nOutput:\n[1,0,2,2]\n\nConstraints:\n1 <= Number of Producers <= 8\n1 <= Number of Consumers <= 8\n1 <= capacity <= 1000\n0 <= element <= 1000\nAt most 1000 calls will be made to enqueue, dequeue, and size.',
    hints: [
      'A producer must wait when the queue is full; a consumer must wait when it is empty.',
      'A lock plus condition variables (one signaling "not full", one signaling "not empty") coordinate producers and consumers.',
      'Equivalently, two semaphores - one counting empty slots, one counting filled slots - block automatically without manual waiting.',
    ],
    intuition:
      'This is the textbook producer-consumer problem, so the two things I must guarantee are mutual exclusion on the shared queue and correct blocking: producers wait while it is full, consumers wait while it is empty. My first, more manual instinct is a single lock plus condition variables. I hold the lock, and inside enqueue I loop-wait on a "not full" condition while the size equals capacity; after adding I signal a "not empty" condition so a waiting consumer can proceed. dequeue mirrors that: wait on "not empty" while size is zero, remove an element, then signal "not full". The while-loop around the wait is important to guard against spurious wakeups. The cleaner, less error-prone design uses two counting semaphores as slot budgets: empty_slots initialized to capacity and filled_slots initialized to 0. enqueue acquires an empty slot (blocking if none), then briefly locks to push and releases a filled slot. dequeue acquires a filled slot (blocking if none), locks to pop, then releases an empty slot. The semaphores handle the blocking automatically, and a small lock still protects the underlying queue from concurrent mutation.',
    walkthrough:
      'Brute force (single lock + condition variables, manual waiting): hold a lock and an internal deque. In enqueue, while the queue size equals capacity, wait on a not_full condition; then append the element and notify the not_empty condition. In dequeue, while the queue is empty, wait on a not_empty condition; then pop and notify not_full. size returns the current count under the lock. Correct, but the explicit predicate-loop waiting is easy to get subtly wrong.\n\nOptimal (two semaphores + lock): keep empty_slots = Semaphore(capacity) and filled_slots = Semaphore(0), a plain deque, and a small mutex. enqueue: acquire empty_slots (blocks when full), lock to append, unlock, release filled_slots. dequeue: acquire filled_slots (blocks when empty), lock to pop, unlock, release empty_slots, return the value. size returns the deque length. The semaphores encode availability so threads block automatically, and the mutex only guards the brief queue mutation.',
    complexityAnalysis:
      'Brute force (lock + conditions): enqueue, dequeue, and size each do O(1) work under the lock (excluding blocking time waiting for the condition); Space O(capacity) for the stored elements.\n\nOptimal (semaphores + lock): enqueue and dequeue each perform O(1) synchronization operations - one semaphore acquire, a short locked mutation, one semaphore release; size is O(1); Space O(capacity) for the queue plus the two semaphores.',
    solutions: {
      python: `import threading
from collections import deque


class Solution:
    # Brute force: single lock + condition variables, manual predicate waits.
    def __init__(self, capacity: int):
        self.capacity = capacity
        self.queue = deque()
        self.lock = threading.Condition()

    def enqueue(self, element: int) -> None:
        with self.lock:
            while len(self.queue) == self.capacity:
                self.lock.wait()
            self.queue.append(element)
            self.lock.notify_all()

    def dequeue(self) -> int:
        with self.lock:
            while len(self.queue) == 0:
                self.lock.wait()
            value = self.queue.popleft()
            self.lock.notify_all()
            return value

    def size(self) -> int:
        with self.lock:
            return len(self.queue)


class SolutionOptimal:
    # Optimal: two semaphores as slot budgets + a small lock.
    def __init__(self, capacity: int):
        self.queue = deque()
        self.empty_slots = threading.Semaphore(capacity)
        self.filled_slots = threading.Semaphore(0)
        self.lock = threading.Lock()

    def enqueue(self, element: int) -> None:
        self.empty_slots.acquire()  # blocks while the queue is full
        with self.lock:
            self.queue.append(element)
        self.filled_slots.release()

    def dequeue(self) -> int:
        self.filled_slots.acquire()  # blocks while the queue is empty
        with self.lock:
            value = self.queue.popleft()
        self.empty_slots.release()
        return value

    def size(self) -> int:
        with self.lock:
            return len(self.queue)
`,
      java: `class Solution {
    // Brute force: single lock + condition variables, manual predicate waits.
    private int capacity;
    private Queue<Integer> queue = new LinkedList<>();
    private final Object lock = new Object();

    public Solution(int capacity) {
        this.capacity = capacity;
    }

    public void enqueue(int element) throws InterruptedException {
        synchronized (lock) {
            while (queue.size() == capacity) {
                lock.wait();
            }
            queue.offer(element);
            lock.notifyAll();
        }
    }

    public int dequeue() throws InterruptedException {
        synchronized (lock) {
            while (queue.isEmpty()) {
                lock.wait();
            }
            int value = queue.poll();
            lock.notifyAll();
            return value;
        }
    }

    public int size() {
        synchronized (lock) {
            return queue.size();
        }
    }
}

class SolutionOptimal {
    // Optimal: two semaphores as slot budgets + a small lock.
    private Queue<Integer> queue = new LinkedList<>();
    private Semaphore emptySlots;
    private Semaphore filledSlots;
    private final Object lock = new Object();

    public SolutionOptimal(int capacity) {
        emptySlots = new Semaphore(capacity);
        filledSlots = new Semaphore(0);
    }

    public void enqueue(int element) throws InterruptedException {
        emptySlots.acquire(); // blocks while the queue is full
        synchronized (lock) {
            queue.offer(element);
        }
        filledSlots.release();
    }

    public int dequeue() throws InterruptedException {
        filledSlots.acquire(); // blocks while the queue is empty
        int value;
        synchronized (lock) {
            value = queue.poll();
        }
        emptySlots.release();
        return value;
    }

    public int size() {
        synchronized (lock) {
            return queue.size();
        }
    }
}
`,
      cpp: `class Solution {
    // Brute force: single mutex + condition variables, manual predicate waits.
private:
    int capacity;
    queue<int> q;
    mutex lock;
    condition_variable notFull;
    condition_variable notEmpty;

public:
    Solution(int capacity) : capacity(capacity) {}

    void enqueue(int element) {
        unique_lock<mutex> guard(lock);
        notFull.wait(guard, [this]() { return (int)q.size() < capacity; });
        q.push(element);
        notEmpty.notify_one();
    }

    int dequeue() {
        unique_lock<mutex> guard(lock);
        notEmpty.wait(guard, [this]() { return !q.empty(); });
        int value = q.front();
        q.pop();
        notFull.notify_one();
        return value;
    }

    int size() {
        unique_lock<mutex> guard(lock);
        return (int)q.size();
    }
};

class SolutionOptimal {
    // Optimal: two counting semaphores as slot budgets + a small mutex.
private:
    queue<int> q;
    counting_semaphore<1000> emptySlots;
    counting_semaphore<1000> filledSlots;
    mutex lock;

public:
    SolutionOptimal(int capacity)
        : emptySlots(capacity), filledSlots(0) {}

    void enqueue(int element) {
        emptySlots.acquire(); // blocks while the queue is full
        {
            lock_guard<mutex> guard(lock);
            q.push(element);
        }
        filledSlots.release();
    }

    int dequeue() {
        filledSlots.acquire(); // blocks while the queue is empty
        int value;
        {
            lock_guard<mutex> guard(lock);
            value = q.front();
            q.pop();
        }
        emptySlots.release();
        return value;
    }

    int size() {
        lock_guard<mutex> guard(lock);
        return (int)q.size();
    }
};
`,
    },
  },
  {
    problemNumber: 198,
    title: 'House Robber',
    slug: 'house-robber',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/house-robber',
    topics: ['Array', 'Dynamic Programming'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.523,
    problemStatement:
      "You are a professional robber planning to rob houses along a street. Each house has a certain amount of money stashed, the only constraint stopping you from robbing each of them is that adjacent houses have security systems connected and it will automatically contact the police if two adjacent houses were broken into on the same night.\n\nGiven an integer array nums representing the amount of money of each house, return the maximum amount of money you can rob tonight without alerting the police.\n\nExample 1:\nInput: nums = [1,2,3,1]\nOutput: 4\nExplanation: Rob house 1 (money = 1) and then rob house 3 (money = 3). Total amount you can rob = 1 + 3 = 4.\n\nExample 2:\nInput: nums = [2,7,9,3,1]\nOutput: 12\nExplanation: Rob house 1 (money = 2), rob house 3 (money = 9) and rob house 5 (money = 1). Total amount you can rob = 2 + 9 + 1 = 12.\n\nConstraints:\n1 <= nums.length <= 100\n0 <= nums[i] <= 400",
    hints: [
      'A pure brute force would try every subset of houses that has no two adjacent indices and take the max sum - that is exponential.',
      'Think about it recursively: at house i, you either rob it (and skip i-1) or skip it (and take the best up to i-1). What is the best result you can get considering only the first i houses?',
      'Once you write the recurrence, notice it only ever needs the previous two answers, not the whole array of subproblems.',
    ],
    intuition:
      'My first idea is to brute force every combination of non-adjacent houses, but with up to 100 houses that is way too many subsets to check. So I think about what decision I am actually making at each house: rob it or skip it. If I rob house i, I get nums[i] plus whatever the best total was up to house i-2 (since I cannot also rob i-1). If I skip house i, I keep whatever the best total was up to house i-1. So the best answer up to house i is just the max of those two options. That is a classic overlapping-subproblems situation, which is the signal for dynamic programming. Once I notice the recurrence only looks back two steps, I realize I do not even need an array to store every subproblem - two running variables are enough.',
    walkthrough:
      'Brute force: write a recursive function rob(i) that returns the best money obtainable from houses i..end. At each call, recurse into rob(i+1) (skip house i) and nums[i] + rob(i+2) (rob house i), and return the max. Without memoization this recomputes the same subproblems exponentially many times.\n\nOptimal bottom-up DP: keep two variables, prevTwo and prevOne, representing the best total considering houses up to i-2 and up to i-1. For each house, compute current = max(prevOne, prevTwo + nums[i]) - either skip this house (keep prevOne) or rob it and add to the best total from two houses back. Then shift prevTwo = prevOne and prevOne = current and move to the next house. At the end prevOne holds the answer.',
    complexityAnalysis:
      'Brute force recursion (no memo): Time O(2^n) because every house branches into two recursive calls with no reuse of repeated subproblems; Space O(n) for the recursion call stack.\n\nOptimal bottom-up DP: Time O(n) because we make a single pass over the houses doing constant work per house; Space O(1) because we only keep two running totals instead of a full DP array.',
    solutions: {
      python: `class Solution:
    def rob(self, nums: List[int]) -> int:
        # Brute force: plain recursion, no memoization.
        # robFrom(i) = best money obtainable from house i onward.
        def robFrom(i):
            if i >= len(nums):
                return 0
            skip_this_house = robFrom(i + 1)
            rob_this_house = nums[i] + robFrom(i + 2)
            return max(skip_this_house, rob_this_house)

        return robFrom(0)


class SolutionOptimal:
    def rob(self, nums: List[int]) -> int:
        # Optimal: bottom-up DP with two rolling variables.
        prev_two = 0  # best total up to two houses back
        prev_one = 0  # best total up to one house back

        for money in nums:
            current = max(prev_one, prev_two + money)
            prev_two = prev_one
            prev_one = current

        return prev_one
`,
      java: `class Solution {
    // Brute force: plain recursion, no memoization.
    public int rob(int[] nums) {
        return robFrom(nums, 0);
    }

    private int robFrom(int[] nums, int i) {
        if (i >= nums.length) {
            return 0;
        }
        int skipThisHouse = robFrom(nums, i + 1);
        int robThisHouse = nums[i] + robFrom(nums, i + 2);
        return Math.max(skipThisHouse, robThisHouse);
    }
}

class SolutionOptimal {
    // Optimal: bottom-up DP with two rolling variables.
    public int rob(int[] nums) {
        int prevTwo = 0;
        int prevOne = 0;

        for (int money : nums) {
            int current = Math.max(prevOne, prevTwo + money);
            prevTwo = prevOne;
            prevOne = current;
        }

        return prevOne;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: plain recursion, no memoization.
    int rob(vector<int>& nums) {
        return robFrom(nums, 0);
    }

private:
    int robFrom(vector<int>& nums, int i) {
        if (i >= (int)nums.size()) {
            return 0;
        }
        int skipThisHouse = robFrom(nums, i + 1);
        int robThisHouse = nums[i] + robFrom(nums, i + 2);
        return max(skipThisHouse, robThisHouse);
    }
};

class SolutionOptimal {
public:
    // Optimal: bottom-up DP with two rolling variables.
    int rob(vector<int>& nums) {
        int prevTwo = 0;
        int prevOne = 0;

        for (int money : nums) {
            int current = max(prevOne, prevTwo + money);
            prevTwo = prevOne;
            prevOne = current;
        }

        return prevOne;
    }
};
`,
    },
  },
  {
    problemNumber: 206,
    title: 'Reverse Linked List',
    slug: 'reverse-linked-list',
    difficulty: 'EASY',
    link: 'https://leetcode.com/problems/reverse-linked-list',
    topics: ['Linked List', 'Recursion'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.7921,
    problemStatement:
      'Given the head of a singly linked list, reverse the list, and return the reversed list.\n\nExample 1:\nInput: head = [1,2,3,4,5]\nOutput: [5,4,3,2,1]\n\nExample 2:\nInput: head = [1,2]\nOutput: [2,1]\n\nExample 3:\nInput: head = []\nOutput: []\n\nConstraints:\nThe number of nodes in the list is the range [0, 5000].\n-5000 <= Node.val <= 5000\n\nFollow up: A linked list can be reversed either iteratively or recursively. Could you implement both?',
    hints: [
      'A brute force approach: read all the values into an array, then build a brand new linked list in reverse order. This uses extra space proportional to the list.',
      'Can you avoid the extra array? Think about what happens if you walk the list once and, for each node, point it backward instead of forward.',
      'You need to remember the previous node before you overwrite current.next, otherwise you lose the rest of the list.',
    ],
    intuition:
      'The first thing I try is the most obvious: copy every value into an array, then build a fresh list in the opposite order. That clearly works but it doubles the memory used. Thinking about it more, I realize I do not actually need a copy - the existing nodes already have everything I need, I just need to flip which direction each node.next points. The trick is that once I rewire current.next to point backward, I will have lost the link to what used to come next, so I have to save that reference before I overwrite it. That is the core idea: walk through with three pointers - the node before, the node I am rewiring, and the node after - and shift all three forward together.',
    walkthrough:
      'Brute force: traverse the list once, copying every val into a list/array. Then build a brand new linked list by iterating that array in reverse, creating new nodes. Return the new head.\n\nOptimal iterative reversal: keep a `prev` pointer starting at null and a `current` pointer starting at head. In each loop iteration, save `current.next` into a temporary `nextNode` (so we do not lose it), then point `current.next` back to `prev`, then advance `prev` to `current` and `current` to `nextNode`. Repeat until `current` is null. At the end, `prev` is the new head of the reversed list.',
    complexityAnalysis:
      'Brute force (array + rebuild): Time O(n) for the single pass to copy values plus O(n) to build new nodes, so O(n) overall; Space O(n) for the array and the newly allocated nodes.\n\nOptimal iterative in-place reversal: Time O(n) because each node is visited and rewired exactly once; Space O(1) because only three pointers are used regardless of list length.',
    solutions: {
      python: `# Definition for singly-linked list.
# class ListNode:
#     def __init__(self, val=0, next=None):
#         self.val = val
#         self.next = next

class Solution:
    def reverseList(self, head: Optional[ListNode]) -> Optional[ListNode]:
        # Brute force: copy values into a list, then build a new
        # linked list in reverse order.
        values = []
        node = head
        while node:
            values.append(node.val)
            node = node.next

        new_head = None
        for value in values:
            new_head = ListNode(value, new_head)

        return new_head


class SolutionOptimal:
    def reverseList(self, head: Optional[ListNode]) -> Optional[ListNode]:
        # Optimal: iteratively rewire next pointers in place.
        previous_node = None
        current_node = head

        while current_node:
            next_node = current_node.next  # save before we overwrite it
            current_node.next = previous_node
            previous_node = current_node
            current_node = next_node

        return previous_node
`,
      java: `// Definition for singly-linked list.
// class ListNode {
//     int val;
//     ListNode next;
//     ListNode() {}
//     ListNode(int val) { this.val = val; }
//     ListNode(int val, ListNode next) { this.val = val; this.next = next; }
// }

class Solution {
    // Brute force: copy values into a list, then build a new
    // linked list in reverse order.
    public ListNode reverseList(ListNode head) {
        List<Integer> values = new ArrayList<>();
        ListNode node = head;
        while (node != null) {
            values.add(node.val);
            node = node.next;
        }

        ListNode newHead = null;
        for (int value : values) {
            newHead = new ListNode(value, newHead);
        }

        return newHead;
    }
}

class SolutionOptimal {
    // Optimal: iteratively rewire next pointers in place.
    public ListNode reverseList(ListNode head) {
        ListNode previousNode = null;
        ListNode currentNode = head;

        while (currentNode != null) {
            ListNode nextNode = currentNode.next;
            currentNode.next = previousNode;
            previousNode = currentNode;
            currentNode = nextNode;
        }

        return previousNode;
    }
}
`,
      cpp: `// Definition for singly-linked list.
// struct ListNode {
//     int val;
//     ListNode *next;
//     ListNode() : val(0), next(nullptr) {}
//     ListNode(int x) : val(x), next(nullptr) {}
//     ListNode(int x, ListNode *next) : val(x), next(next) {}
// };

class Solution {
public:
    // Brute force: copy values into a vector, then build a new
    // linked list in reverse order.
    ListNode* reverseList(ListNode* head) {
        vector<int> values;
        ListNode* node = head;
        while (node != nullptr) {
            values.push_back(node->val);
            node = node->next;
        }

        ListNode* newHead = nullptr;
        for (int value : values) {
            newHead = new ListNode(value, newHead);
        }

        return newHead;
    }
};

class SolutionOptimal {
public:
    // Optimal: iteratively rewire next pointers in place.
    ListNode* reverseList(ListNode* head) {
        ListNode* previousNode = nullptr;
        ListNode* currentNode = head;

        while (currentNode != nullptr) {
            ListNode* nextNode = currentNode->next;
            currentNode->next = previousNode;
            previousNode = currentNode;
            currentNode = nextNode;
        }

        return previousNode;
    }
};
`,
    },
  },
  {
    problemNumber: 210,
    title: 'Course Schedule II',
    slug: 'course-schedule-ii',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/course-schedule-ii',
    topics: ['Depth-First Search', 'Breadth-First Search', 'Graph', 'Topological Sort'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.5342,
    problemStatement:
      'There are a total of numCourses courses you have to take, labeled from 0 to numCourses - 1. You are given an array prerequisites where prerequisites[i] = [ai, bi] indicates that you must take course bi first if you want to take course ai.\n\nReturn the ordering of courses you should take to finish all courses. If there are many valid answers, return any of them. If it is impossible to finish all courses, return an empty array.\n\nExample 1:\nInput: numCourses = 2, prerequisites = [[1,0]]\nOutput: [0,1]\nExplanation: There are a total of 2 courses to take. To take course 1 you should have finished course 0. So the correct course order is [0,1].\n\nExample 2:\nInput: numCourses = 4, prerequisites = [[1,0],[2,0],[3,1],[3,2]]\nOutput: [0,1,2,3]\nExplanation: There are a total of 4 courses. To take course 3 you should have finished both courses 1 and 2. Both courses 1 and 2 should be taken after you finished course 0. So one correct course order is [0,1,2,3]. Another correct ordering is [0,2,1,3].\n\nExample 3:\nInput: numCourses = 1, prerequisites = []\nOutput: [0]\n\nConstraints:\n1 <= numCourses <= 2000\n0 <= prerequisites.length <= numCourses * (numCourses - 1)\nprerequisites[i].length == 2\n0 <= ai, bi < numCourses\nai != bi\nAll the pairs [ai, bi] are distinct.',
    hints: [
      'This is really asking for a valid ordering of a directed graph, which only exists if the graph has no cycle.',
      'A brute force way to build an ordering: repeatedly scan all remaining courses for one whose prerequisites are already satisfied, add it to the result, and repeat. This is correct but wastes time rescanning every course on every step.',
      'Kahn\'s algorithm formalizes this with in-degrees and a queue: track how many prerequisites each course still has left, and whenever a course reaches zero, it is safe to take next.',
    ],
    intuition:
      'This problem is really about ordering nodes in a directed graph so that every prerequisite comes before the course that needs it - that is a topological sort. My first instinct (brute force) is to simulate it literally: keep scanning the list of remaining courses, and any time I find one whose prerequisites are all already taken, take it and remove it from consideration; repeat until done or stuck. That works but it means re-scanning all remaining courses over and over, which is wasteful. The cleaner version of the same idea is Kahn\'s algorithm: instead of re-scanning, I track an in-degree (number of unmet prerequisites) for every course. Any course with in-degree zero can be taken right away, so I put those in a queue. Whenever I "complete" a course, I decrement the in-degree of everything that depended on it, and if any of those drop to zero, they go into the queue too. This way each course and each edge is only ever processed once.',
    walkthrough:
      'Brute force: build an adjacency structure of prerequisites. Repeatedly loop over all courses not yet scheduled; for each one, check if every prerequisite is already in the result list. If yes, add it to the result. Keep looping over the full remaining set until no more progress is made in a full pass, or until everything is scheduled. If a full pass adds nothing new and courses remain, there is a cycle - return an empty array.\n\nOptimal Kahn\'s algorithm (BFS topological sort): build an adjacency list graph[b] = list of courses that depend on b, and an inDegree array counting unmet prerequisites for each course. Initialize a queue with every course whose inDegree is 0. While the queue is not empty, pop a course, append it to the result order, then for every course that depends on it, decrement that course\'s inDegree, and if it hits 0, push it onto the queue. At the end, if the result order has all numCourses courses, return it; otherwise a cycle blocked some courses, so return an empty array.',
    complexityAnalysis:
      'Brute force repeated scanning: Time O(V^2 + V*E) in the worst case since each of the V passes can rescan all courses and their prerequisite lists; Space O(V + E) for the adjacency structure and result list.\n\nOptimal Kahn\'s algorithm: Time O(V + E) because every course is enqueued and dequeued exactly once, and every prerequisite edge is examined exactly once when decrementing in-degrees; Space O(V + E) for the adjacency list, in-degree array, and queue.',
    solutions: {
      python: `class Solution:
    def findOrder(self, numCourses: int, prerequisites: List[List[int]]) -> List[int]:
        # Brute force: repeatedly scan all unscheduled courses and take
        # any whose prerequisites are already satisfied.
        prereqs_of = {course: [] for course in range(numCourses)}
        for course, prereq in prerequisites:
            prereqs_of[course].append(prereq)

        taken = []
        taken_set = set()
        remaining = set(range(numCourses))

        progress = True
        while remaining and progress:
            progress = False
            for course in list(remaining):
                if all(p in taken_set for p in prereqs_of[course]):
                    taken.append(course)
                    taken_set.add(course)
                    remaining.remove(course)
                    progress = True

        if remaining:
            return []  # a cycle blocked some courses
        return taken


class SolutionOptimal:
    def findOrder(self, numCourses: int, prerequisites: List[List[int]]) -> List[int]:
        # Optimal: Kahn's algorithm, BFS topological sort using in-degrees.
        graph = {course: [] for course in range(numCourses)}
        in_degree = [0] * numCourses

        for course, prereq in prerequisites:
            graph[prereq].append(course)
            in_degree[course] += 1

        queue = deque([course for course in range(numCourses) if in_degree[course] == 0])
        order = []

        while queue:
            course = queue.popleft()
            order.append(course)
            for dependent in graph[course]:
                in_degree[dependent] -= 1
                if in_degree[dependent] == 0:
                    queue.append(dependent)

        if len(order) == numCourses:
            return order
        return []  # a cycle blocked some courses
`,
      java: `class Solution {
    // Brute force: repeatedly scan all unscheduled courses and take
    // any whose prerequisites are already satisfied.
    public int[] findOrder(int numCourses, int[][] prerequisites) {
        List<List<Integer>> prereqsOf = new ArrayList<>();
        for (int i = 0; i < numCourses; i++) {
            prereqsOf.add(new ArrayList<>());
        }
        for (int[] edge : prerequisites) {
            prereqsOf.get(edge[0]).add(edge[1]);
        }

        boolean[] taken = new boolean[numCourses];
        List<Integer> order = new ArrayList<>();
        boolean progress = true;
        int remainingCount = numCourses;

        while (remainingCount > 0 && progress) {
            progress = false;
            for (int course = 0; course < numCourses; course++) {
                if (taken[course]) {
                    continue;
                }
                boolean allPrereqsTaken = true;
                for (int prereq : prereqsOf.get(course)) {
                    if (!taken[prereq]) {
                        allPrereqsTaken = false;
                        break;
                    }
                }
                if (allPrereqsTaken) {
                    taken[course] = true;
                    order.add(course);
                    remainingCount--;
                    progress = true;
                }
            }
        }

        if (remainingCount > 0) {
            return new int[0];
        }
        return order.stream().mapToInt(Integer::intValue).toArray();
    }
}

class SolutionOptimal {
    // Optimal: Kahn's algorithm, BFS topological sort using in-degrees.
    public int[] findOrder(int numCourses, int[][] prerequisites) {
        List<List<Integer>> graph = new ArrayList<>();
        for (int i = 0; i < numCourses; i++) {
            graph.add(new ArrayList<>());
        }
        int[] inDegree = new int[numCourses];

        for (int[] edge : prerequisites) {
            int course = edge[0];
            int prereq = edge[1];
            graph.get(prereq).add(course);
            inDegree[course]++;
        }

        Queue<Integer> queue = new LinkedList<>();
        for (int course = 0; course < numCourses; course++) {
            if (inDegree[course] == 0) {
                queue.add(course);
            }
        }

        int[] order = new int[numCourses];
        int index = 0;

        while (!queue.isEmpty()) {
            int course = queue.poll();
            order[index++] = course;
            for (int dependent : graph.get(course)) {
                inDegree[dependent]--;
                if (inDegree[dependent] == 0) {
                    queue.add(dependent);
                }
            }
        }

        if (index == numCourses) {
            return order;
        }
        return new int[0];
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: repeatedly scan all unscheduled courses and take
    // any whose prerequisites are already satisfied.
    vector<int> findOrder(int numCourses, vector<vector<int>>& prerequisites) {
        vector<vector<int>> prereqsOf(numCourses);
        for (auto& edge : prerequisites) {
            prereqsOf[edge[0]].push_back(edge[1]);
        }

        vector<bool> taken(numCourses, false);
        vector<int> order;
        bool progress = true;
        int remainingCount = numCourses;

        while (remainingCount > 0 && progress) {
            progress = false;
            for (int course = 0; course < numCourses; course++) {
                if (taken[course]) {
                    continue;
                }
                bool allPrereqsTaken = true;
                for (int prereq : prereqsOf[course]) {
                    if (!taken[prereq]) {
                        allPrereqsTaken = false;
                        break;
                    }
                }
                if (allPrereqsTaken) {
                    taken[course] = true;
                    order.push_back(course);
                    remainingCount--;
                    progress = true;
                }
            }
        }

        if (remainingCount > 0) {
            return {};
        }
        return order;
    }
};

class SolutionOptimal {
public:
    // Optimal: Kahn's algorithm, BFS topological sort using in-degrees.
    vector<int> findOrder(int numCourses, vector<vector<int>>& prerequisites) {
        vector<vector<int>> graph(numCourses);
        vector<int> inDegree(numCourses, 0);

        for (auto& edge : prerequisites) {
            int course = edge[0];
            int prereq = edge[1];
            graph[prereq].push_back(course);
            inDegree[course]++;
        }

        queue<int> q;
        for (int course = 0; course < numCourses; course++) {
            if (inDegree[course] == 0) {
                q.push(course);
            }
        }

        vector<int> order;
        while (!q.empty()) {
            int course = q.front();
            q.pop();
            order.push_back(course);
            for (int dependent : graph[course]) {
                inDegree[dependent]--;
                if (inDegree[dependent] == 0) {
                    q.push(dependent);
                }
            }
        }

        if ((int)order.size() == numCourses) {
            return order;
        }
        return {};
    }
};
`,
    },
  },
  {
    problemNumber: 297,
    title: 'Serialize and Deserialize Binary Tree',
    slug: 'serialize-and-deserialize-binary-tree',
    difficulty: 'HARD',
    link: 'https://leetcode.com/problems/serialize-and-deserialize-binary-tree',
    topics: ['String', 'Tree', 'Depth-First Search', 'Breadth-First Search', 'Design', 'Binary Tree'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.5897,
    problemStatement:
      'Serialization is the process of converting a data structure or object into a sequence of bits so that it can be stored in a file or memory buffer, or transmitted across a network connection link to be reconstructed later in the same or another computer environment.\n\nDesign an algorithm to serialize and deserialize a binary tree. There is no restriction on how your serialization/deserialization algorithm should work. You just need to ensure that a binary tree can be serialized to a string and this string can be deserialized to the original tree structure.\n\nClarification: The input/output format is the same as how LeetCode serializes a binary tree. You do not necessarily need to follow this format.\n\nExample 1:\nInput: root = [1,2,3,null,null,4,5]\nOutput: [1,2,3,null,null,4,5]\n\nExample 2:\nInput: root = []\nOutput: []\n\nConstraints:\nThe number of nodes in the tree is in the range [0, 10^4].\n-1000 <= Node.val <= 1000',
    hints: [
      'A brute force way is to record every node value level by level (BFS), using a placeholder for missing children, similar to how LeetCode itself displays trees - but you need to also store null markers carefully so you can rebuild the exact shape.',
      'A cleaner approach: use preorder DFS (root, then left subtree, then right subtree), and explicitly write a marker like "null" whenever a child is missing. Because every null is recorded, deserialization can rebuild the tree unambiguously by consuming tokens in the same order.',
      'Deserialization should consume the token stream with the same traversal order used to produce it - usually with an index pointer or an iterator over the split tokens.',
    ],
    intuition:
      'The core difficulty is that a plain inorder or level traversal does not, by itself, capture the shape of the tree - you cannot tell where children are missing unless you record that explicitly. My first idea (a kind of brute force) is to do a level-order (BFS) traversal and write down every node\'s value, but I quickly realize I need to write a placeholder for every missing child too, even at the deepest level, otherwise I cannot reconstruct parent-child relationships correctly. Thinking about it more, a preorder DFS is actually simpler to reason about: if I always write the current node first, then recursively serialize the left subtree, then the right subtree, and I always write a "null" marker for missing children, then the resulting string fully and unambiguously describes the tree. Deserializing is just doing the same traversal in reverse: read one token, if it is "null" return an empty subtree, otherwise create a node and recursively read its left and then right subtree from the rest of the stream.',
    walkthrough:
      'Brute force level-order with explicit null markers: serialize by doing BFS, pushing every node (or a "null" placeholder for missing children) into the output, including the placeholders\' "missing children" so the tree boundary is unambiguous. Deserialize by reading values back in BFS order and wiring up children level by level using a queue. This works but is fiddly to get exactly right because the queue bookkeeping for null children needs care.\n\nOptimal preorder DFS with null markers: serialize(node) appends node.val if node exists, then recursively serializes node.left, then node.right; if node is null, it appends a sentinel like "null". Join all the appended tokens with a delimiter (e.g. comma) into one string. Deserialize splits the string back into tokens and processes them with an index/iterator: build(tokens) reads the next token; if it is "null", consume it and return null; otherwise create a new TreeNode with that value, then recursively call build(tokens) for the left child and again for the right child, attaching the results, and return the node.',
    complexityAnalysis:
      'Brute force level-order with queue: Time O(n) since every node and null placeholder is visited once during both serialize and deserialize; Space O(n) for the queue and output string, proportional to the number of nodes (including null markers).\n\nOptimal preorder DFS: Time O(n) because serialize visits every node exactly once and deserialize consumes every token exactly once; Space O(n) for the output string/token list, plus O(h) additional space for the recursion stack where h is the tree height (up to O(n) for a skewed tree).',
    solutions: {
      python: `# Definition for a binary tree node.
# class TreeNode:
#     def __init__(self, val=0, left=None, right=None):
#         self.val = val
#         self.left = left
#         self.right = right

class Solution:
    # Brute force: level-order (BFS) serialization, recording "null"
    # placeholders for every missing child so the shape is preserved.
    def serialize(self, root: Optional[TreeNode]) -> str:
        if not root:
            return ''

        tokens = []
        queue = deque([root])
        while queue:
            node = queue.popleft()
            if node is None:
                tokens.append('null')
                continue
            tokens.append(str(node.val))
            queue.append(node.left)
            queue.append(node.right)

        return ','.join(tokens)

    def deserialize(self, data: str) -> Optional[TreeNode]:
        if not data:
            return None

        tokens = data.split(',')
        root = TreeNode(int(tokens[0]))
        queue = deque([root])
        index = 1

        while queue and index < len(tokens):
            node = queue.popleft()

            left_token = tokens[index]
            index += 1
            if left_token != 'null':
                node.left = TreeNode(int(left_token))
                queue.append(node.left)

            if index < len(tokens):
                right_token = tokens[index]
                index += 1
                if right_token != 'null':
                    node.right = TreeNode(int(right_token))
                    queue.append(node.right)

        return root


class SolutionOptimal:
    # Optimal: preorder DFS serialization with explicit null markers.
    def serialize(self, root: Optional[TreeNode]) -> str:
        tokens = []

        def dfs(node):
            if node is None:
                tokens.append('null')
                return
            tokens.append(str(node.val))
            dfs(node.left)
            dfs(node.right)

        dfs(root)
        return ','.join(tokens)

    def deserialize(self, data: str) -> Optional[TreeNode]:
        tokens = iter(data.split(','))

        def build():
            token = next(tokens)
            if token == 'null':
                return None
            node = TreeNode(int(token))
            node.left = build()
            node.right = build()
            return node

        return build()
`,
      java: `// Definition for a binary tree node.
// public class TreeNode {
//     int val;
//     TreeNode left;
//     TreeNode right;
//     TreeNode() {}
//     TreeNode(int val) { this.val = val; }
//     TreeNode(int val, TreeNode left, TreeNode right) {
//         this.val = val;
//         this.left = left;
//         this.right = right;
//     }
// }

class Solution {
    // Brute force: level-order (BFS) serialization, recording "null"
    // placeholders for every missing child so the shape is preserved.
    public String serialize(TreeNode root) {
        if (root == null) {
            return "";
        }

        List<String> tokens = new ArrayList<>();
        Queue<TreeNode> queue = new LinkedList<>();
        queue.add(root);

        while (!queue.isEmpty()) {
            TreeNode node = queue.poll();
            if (node == null) {
                tokens.add("null");
                continue;
            }
            tokens.add(String.valueOf(node.val));
            queue.add(node.left);
            queue.add(node.right);
        }

        return String.join(",", tokens);
    }

    public TreeNode deserialize(String data) {
        if (data.isEmpty()) {
            return null;
        }

        String[] tokens = data.split(",");
        TreeNode root = new TreeNode(Integer.parseInt(tokens[0]));
        Queue<TreeNode> queue = new LinkedList<>();
        queue.add(root);
        int index = 1;

        while (!queue.isEmpty() && index < tokens.length) {
            TreeNode node = queue.poll();

            String leftToken = tokens[index++];
            if (!leftToken.equals("null")) {
                node.left = new TreeNode(Integer.parseInt(leftToken));
                queue.add(node.left);
            }

            if (index < tokens.length) {
                String rightToken = tokens[index++];
                if (!rightToken.equals("null")) {
                    node.right = new TreeNode(Integer.parseInt(rightToken));
                    queue.add(node.right);
                }
            }
        }

        return root;
    }
}

class SolutionOptimal {
    // Optimal: preorder DFS serialization with explicit null markers.
    public String serialize(TreeNode root) {
        StringBuilder builder = new StringBuilder();
        serializeHelper(root, builder);
        return builder.toString();
    }

    private void serializeHelper(TreeNode node, StringBuilder builder) {
        if (node == null) {
            builder.append("null").append(",");
            return;
        }
        builder.append(node.val).append(",");
        serializeHelper(node.left, builder);
        serializeHelper(node.right, builder);
    }

    public TreeNode deserialize(String data) {
        Queue<String> tokens = new LinkedList<>(Arrays.asList(data.split(",")));
        return deserializeHelper(tokens);
    }

    private TreeNode deserializeHelper(Queue<String> tokens) {
        String token = tokens.poll();
        if (token.equals("null")) {
            return null;
        }
        TreeNode node = new TreeNode(Integer.parseInt(token));
        node.left = deserializeHelper(tokens);
        node.right = deserializeHelper(tokens);
        return node;
    }
}
`,
      cpp: `// Definition for a binary tree node.
// struct TreeNode {
//     int val;
//     TreeNode *left;
//     TreeNode *right;
//     TreeNode() : val(0), left(nullptr), right(nullptr) {}
//     TreeNode(int x) : val(x), left(nullptr), right(nullptr) {}
//     TreeNode(int x, TreeNode *left, TreeNode *right) : val(x), left(left), right(right) {}
// };

class Solution {
public:
    // Brute force: level-order (BFS) serialization, recording "null"
    // placeholders for every missing child so the shape is preserved.
    string serialize(TreeNode* root) {
        if (root == nullptr) {
            return "";
        }

        vector<string> tokens;
        queue<TreeNode*> q;
        q.push(root);

        while (!q.empty()) {
            TreeNode* node = q.front();
            q.pop();
            if (node == nullptr) {
                tokens.push_back("null");
                continue;
            }
            tokens.push_back(to_string(node->val));
            q.push(node->left);
            q.push(node->right);
        }

        string result;
        for (int i = 0; i < (int)tokens.size(); i++) {
            if (i > 0) result += ',';
            result += tokens[i];
        }
        return result;
    }

    TreeNode* deserialize(string data) {
        if (data.empty()) {
            return nullptr;
        }

        vector<string> tokens;
        stringstream ss(data);
        string token;
        while (getline(ss, token, ',')) {
            tokens.push_back(token);
        }

        TreeNode* root = new TreeNode(stoi(tokens[0]));
        queue<TreeNode*> q;
        q.push(root);
        int index = 1;

        while (!q.empty() && index < (int)tokens.size()) {
            TreeNode* node = q.front();
            q.pop();

            string leftToken = tokens[index++];
            if (leftToken != "null") {
                node->left = new TreeNode(stoi(leftToken));
                q.push(node->left);
            }

            if (index < (int)tokens.size()) {
                string rightToken = tokens[index++];
                if (rightToken != "null") {
                    node->right = new TreeNode(stoi(rightToken));
                    q.push(node->right);
                }
            }
        }

        return root;
    }
};

class SolutionOptimal {
public:
    // Optimal: preorder DFS serialization with explicit null markers.
    string serialize(TreeNode* root) {
        string result;
        serializeHelper(root, result);
        return result;
    }

    TreeNode* deserialize(string data) {
        vector<string> tokens;
        stringstream ss(data);
        string token;
        while (getline(ss, token, ',')) {
            tokens.push_back(token);
        }
        int index = 0;
        return deserializeHelper(tokens, index);
    }

private:
    void serializeHelper(TreeNode* node, string& result) {
        if (node == nullptr) {
            result += "null,";
            return;
        }
        result += to_string(node->val) + ',';
        serializeHelper(node->left, result);
        serializeHelper(node->right, result);
    }

    TreeNode* deserializeHelper(vector<string>& tokens, int& index) {
        string token = tokens[index++];
        if (token == "null") {
            return nullptr;
        }
        TreeNode* node = new TreeNode(stoi(token));
        node->left = deserializeHelper(tokens, index);
        node->right = deserializeHelper(tokens, index);
        return node;
    }
};
`,
    },
  },
  {
    problemNumber: 348,
    title: 'Design Tic-Tac-Toe',
    slug: 'design-tic-tac-toe',
    difficulty: 'MEDIUM',
    link: 'https://leetcode.com/problems/design-tic-tac-toe',
    topics: ['Array', 'Hash Table', 'Design', 'Matrix', 'Simulation'],
    companies: ['Tesla'],
    frequency: 54.1,
    acceptanceRate: 0.586,
    problemStatement:
      'Design a Tic-Tac-Toe game that is played between two players on an n x n grid.\n\nImplement the TicTacToe class:\nTicTacToe(int n) Initializes the object the size of the board n.\nint move(int row, int col, int player) Indicates that the player with id player plays at the cell (row, col) of the board. The move is guaranteed to be a valid move, and the two players alternate in making moves. Return:\n0 if there is no winner after the move,\n1 if player 1 is the winner after the move, or\n2 if player 2 is the winner after the move.\n\nExample 1:\nInput\n["TicTacToe", "move", "move", "move", "move", "move", "move", "move"]\n[[3], [0, 0, 1], [0, 2, 2], [2, 2, 1], [1, 1, 2], [2, 0, 1], [1, 0, 2], [2, 1, 1]]\nOutput\n[null, 0, 0, 0, 0, 0, 0, 1]\n\nExplanation\nTicTacToe ticTacToe = new TicTacToe(3);\nAssume that player 1 is "X" and player 2 is "O" in the board.\nticTacToe.move(0, 0, 1); // call(0, 0, 1) -> board has X in row 0 col 0, returns 0 since no winner\nticTacToe.move(0, 2, 2); // call(0, 2, 2) -> board has O in row 0 col 2, returns 0\nticTacToe.move(2, 2, 1); // call(2, 2, 1) -> board has X in row 2 col 2, returns 0\nticTacToe.move(1, 1, 2); // call(1, 1, 2) -> board has O in row 1 col 1, returns 0\nticTacToe.move(2, 0, 1); // call(2, 0, 1) -> board has X in row 2 col 0, returns 0\nticTacToe.move(1, 0, 2); // call(1, 0, 2) -> board has O in row 1 col 0, returns 0\nticTacToe.move(2, 1, 1); // call(2, 1, 1) -> board has X in row 2 col 1, returns 1 since X wins the diagonal\n\nConstraints:\n2 <= n <= 100\nplayer is 1 or 2\n0 <= row, col < n\n(row, col) are unique for each different call to move.\nAt most n^2 calls will be made to move.',
    hints: [
      'A brute force way: keep the full n x n board, and after every move re-scan all rows, all columns, and both diagonals to check if any one of them is filled entirely by the same player.',
      'That rescan is wasteful since only one row, one column, and possibly one diagonal could even be affected by the move you just made - the rest could not have changed.',
      'Instead of storing the whole board, can you keep a running count per row and per column (and the two diagonals) of how many marks each player has placed, using positive counts for player 1 and negative counts for player 2? A row/column hits a win the moment its count reaches +n or -n.',
    ],
    intuition:
      'The naive way to check for a winner is to keep the whole board and, after every move, scan every row, every column, and the two diagonals to see if any of them is completely filled by one player - that is the obvious brute force, but it does a lot of unnecessary rechecking, since a move can only possibly complete the row and column it was placed in (and maybe a diagonal). That observation is the key: I do not need to track the whole board\'s content, only running counts. For each row I keep a counter; +1 when player 1 places a mark there, -1 when player 2 does. If that counter ever reaches +n, player 1 has filled the whole row; if it reaches -n, player 2 has. The same trick applies to columns and to the two diagonals (using +1/-1 the same way). This turns an O(n) or O(n^2) check per move into an O(1) check, since I only ever touch the few counters affected by the current move.',
    walkthrough:
      'Brute force: store the full board as an n x n grid; in move(row, col, player), write player into board[row][col], then loop over all n cells in that row to see if they all equal player, loop over all n cells in that column similarly, and if the move lies on either diagonal, check that diagonal too. Return the player if any full line matches, otherwise 0.\n\nOptimal running counters: maintain rows[n], cols[n], and two scalars diagonal and antiDiagonal. In move(row, col, player), use delta = +1 if player == 1 else -1. Add delta to rows[row] and cols[col]. If row == col, also add delta to diagonal. If row + col == n - 1, also add delta to antiDiagonal. After updating, check if the absolute value of rows[row], cols[col], diagonal, or antiDiagonal equals n; if so, the player who just moved has won (return player), otherwise return 0.',
    complexityAnalysis:
      'Brute force full-board rescan: Time O(n) per move because each call rescans one row and one column (and possibly a diagonal) of length n; Space O(n^2) for storing the entire board.\n\nOptimal running counters: Time O(1) per move because we only update and check a constant number of counters (one row counter, one column counter, and possibly the two diagonal counters); Space O(n) for the row and column counter arrays, plus O(1) for the two diagonal counters.',
    solutions: {
      python: `class Solution:
    # Brute force: store the whole board, rescan the affected row,
    # column, and diagonals after every move.
    def __init__(self, n: int):
        self.n = n
        self.board = [[0] * n for _ in range(n)]

    def move(self, row: int, col: int, player: int) -> int:
        self.board[row][col] = player
        n = self.n

        if all(self.board[row][c] == player for c in range(n)):
            return player
        if all(self.board[r][col] == player for r in range(n)):
            return player
        if row == col and all(self.board[i][i] == player for i in range(n)):
            return player
        if row + col == n - 1 and all(self.board[i][n - 1 - i] == player for i in range(n)):
            return player

        return 0


class SolutionOptimal:
    # Optimal: running counters per row/column/diagonal, +1 for
    # player 1 and -1 for player 2. A line is won when |count| == n.
    def __init__(self, n: int):
        self.n = n
        self.rows = [0] * n
        self.cols = [0] * n
        self.diagonal = 0
        self.anti_diagonal = 0

    def move(self, row: int, col: int, player: int) -> int:
        delta = 1 if player == 1 else -1
        n = self.n

        self.rows[row] += delta
        self.cols[col] += delta
        if row == col:
            self.diagonal += delta
        if row + col == n - 1:
            self.anti_diagonal += delta

        if abs(self.rows[row]) == n or abs(self.cols[col]) == n:
            return player
        if abs(self.diagonal) == n or abs(self.anti_diagonal) == n:
            return player

        return 0
`,
      java: `class Solution {
    // Brute force: store the whole board, rescan the affected row,
    // column, and diagonals after every move.
    private int n;
    private int[][] board;

    public Solution(int n) {
        this.n = n;
        this.board = new int[n][n];
    }

    public int move(int row, int col, int player) {
        board[row][col] = player;

        boolean rowWin = true;
        for (int c = 0; c < n; c++) {
            if (board[row][c] != player) {
                rowWin = false;
                break;
            }
        }
        if (rowWin) return player;

        boolean colWin = true;
        for (int r = 0; r < n; r++) {
            if (board[r][col] != player) {
                colWin = false;
                break;
            }
        }
        if (colWin) return player;

        if (row == col) {
            boolean diagWin = true;
            for (int i = 0; i < n; i++) {
                if (board[i][i] != player) {
                    diagWin = false;
                    break;
                }
            }
            if (diagWin) return player;
        }

        if (row + col == n - 1) {
            boolean antiDiagWin = true;
            for (int i = 0; i < n; i++) {
                if (board[i][n - 1 - i] != player) {
                    antiDiagWin = false;
                    break;
                }
            }
            if (antiDiagWin) return player;
        }

        return 0;
    }
}

class SolutionOptimal {
    // Optimal: running counters per row/column/diagonal, +1 for
    // player 1 and -1 for player 2. A line is won when |count| == n.
    private int n;
    private int[] rows;
    private int[] cols;
    private int diagonal;
    private int antiDiagonal;

    public SolutionOptimal(int n) {
        this.n = n;
        this.rows = new int[n];
        this.cols = new int[n];
    }

    public int move(int row, int col, int player) {
        int delta = (player == 1) ? 1 : -1;

        rows[row] += delta;
        cols[col] += delta;
        if (row == col) {
            diagonal += delta;
        }
        if (row + col == n - 1) {
            antiDiagonal += delta;
        }

        if (Math.abs(rows[row]) == n || Math.abs(cols[col]) == n) {
            return player;
        }
        if (Math.abs(diagonal) == n || Math.abs(antiDiagonal) == n) {
            return player;
        }

        return 0;
    }
}
`,
      cpp: `class Solution {
public:
    // Brute force: store the whole board, rescan the affected row,
    // column, and diagonals after every move.
    Solution(int n) : n(n), board(n, vector<int>(n, 0)) {}

    int move(int row, int col, int player) {
        board[row][col] = player;

        bool rowWin = true;
        for (int c = 0; c < n; c++) {
            if (board[row][c] != player) {
                rowWin = false;
                break;
            }
        }
        if (rowWin) return player;

        bool colWin = true;
        for (int r = 0; r < n; r++) {
            if (board[r][col] != player) {
                colWin = false;
                break;
            }
        }
        if (colWin) return player;

        if (row == col) {
            bool diagWin = true;
            for (int i = 0; i < n; i++) {
                if (board[i][i] != player) {
                    diagWin = false;
                    break;
                }
            }
            if (diagWin) return player;
        }

        if (row + col == n - 1) {
            bool antiDiagWin = true;
            for (int i = 0; i < n; i++) {
                if (board[i][n - 1 - i] != player) {
                    antiDiagWin = false;
                    break;
                }
            }
            if (antiDiagWin) return player;
        }

        return 0;
    }

private:
    int n;
    vector<vector<int>> board;
};

class SolutionOptimal {
public:
    // Optimal: running counters per row/column/diagonal, +1 for
    // player 1 and -1 for player 2. A line is won when |count| == n.
    SolutionOptimal(int n) : n(n), rows(n, 0), cols(n, 0), diagonal(0), antiDiagonal(0) {}

    int move(int row, int col, int player) {
        int delta = (player == 1) ? 1 : -1;

        rows[row] += delta;
        cols[col] += delta;
        if (row == col) {
            diagonal += delta;
        }
        if (row + col == n - 1) {
            antiDiagonal += delta;
        }

        if (abs(rows[row]) == n || abs(cols[col]) == n) {
            return player;
        }
        if (abs(diagonal) == n || abs(antiDiagonal) == n) {
            return player;
        }

        return 0;
    }

private:
    int n;
    vector<int> rows;
    vector<int> cols;
    int diagonal;
    int antiDiagonal;
};
`,
    },
  },
]
