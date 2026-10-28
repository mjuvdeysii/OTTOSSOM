// A fast copy of Tools/engine.py's rules for the level search only (gen3.py). Levels that ship are always solved
// again by engine.py (build_levels.py) and by the Swift engine (test target), so this file never decides a par.
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

typedef struct { int8_t moss, otto, face, mosto; uint64_t blocks, filled; } S;

static int W, H, N, MODE, BEAD, CROWN;      // MODE 0 none 1 shadow 2 pair 3 mirror
static char G[64];                           // '.', '_', 'T', '='
static const int DX[4] = {0, 1, 0, -1}, DY[4] = {-1, 0, 1, 0};
static const int MIRROR[4] = {0, 3, 2, 1};

// ---- lit cache ----
typedef struct { int8_t otto, face, used; uint64_t blocks, filled, lit; } LC;
static LC *lc; static size_t lcn, lccount;
static inline uint64_t hmix(uint64_t x) { x ^= x >> 33; x *= 0xff51afd7ed558ccdULL; x ^= x >> 33; x *= 0xc4ceb9fe1a85ec53ULL; x ^= x >> 33; return x; }

static inline char ground(const S *s, int i) {
    char g = G[i];
    if ((g == '_' || g == '=') && (s->filled >> i & 1)) return '.';
    return g;
}
static inline int blocks_light(const S *s, int i) { return ground(s, i) == 'T' || (s->blocks >> i & 1); }

static int los(const S *s, int ax, int ay, int bx, int by) {
    int n = 4 * (abs(bx - ax) > abs(by - ay) ? abs(bx - ax) : abs(by - ay));
    for (int i = 1; i < n; i++) {
        int cx = (2 * (ax * n + (bx - ax) * i) + n) / (2 * n);
        int cy = (2 * (ay * n + (by - ay) * i) + n) / (2 * n);
        if ((cx == ax && cy == ay) || (cx == bx && cy == by)) continue;
        if (blocks_light(s, cy * W + cx)) return 0;
    }
    return 1;
}

static uint64_t compute_lit(const S *s) {
    int ox = s->otto % W, oy = s->otto / W; uint64_t out = 0;
    for (int dx = -1; dx <= 1; dx++) for (int dy = -1; dy <= 1; dy++) {
        int x = ox + dx, y = oy + dy;
        if (x >= 0 && y >= 0 && x < W && y < H) out |= 1ULL << (y * W + x);
    }
    int fx = DX[s->face], fy = DY[s->face], lx = -fy, ly = fx, m = W > H ? W : H;
    for (int f = 1; f <= m; f++) for (int l = -f; l <= f; l++) {
        int x = ox + fx * f + lx * l, y = oy + fy * f + ly * l;
        if (x < 0 || y < 0 || x >= W || y >= H) continue;
        int q = y * W + x;
        if (out >> q & 1) continue;
        if (los(s, ox, oy, x, y)) out |= 1ULL << q;
    }
    return out;
}

static uint64_t lit(const S *s) {
    uint64_t h = hmix(s->blocks * 31 + s->filled * 1000003ULL + (uint64_t)s->otto * 131 + s->face);
    size_t i = h & (lcn - 1);
    while (lc[i].used) {
        if (lc[i].otto == s->otto && lc[i].face == s->face && lc[i].blocks == s->blocks && lc[i].filled == s->filled) return lc[i].lit;
        i = (i + 1) & (lcn - 1);
    }
    uint64_t v = compute_lit(s);
    if (++lccount > lcn * 7 / 10) { memset(lc, 0, sizeof(LC) * lcn); lccount = 1; i = h & (lcn - 1); }
    lc[i].used = 1; lc[i].otto = s->otto; lc[i].face = s->face; lc[i].blocks = s->blocks; lc[i].filled = s->filled; lc[i].lit = v;
    return v;
}

static int nb(int i, int d) {
    int x = i % W + DX[d], y = i / W + DY[d];
    if (x < 0 || y < 0 || x >= W || y >= H) return -1;
    return y * W + x;
}

// push the block at q in direction d; returns 0 if impossible
static int push(S *s, int q, int d, int o1, int o2, int o3) {
    int r = nb(q, d);
    if (r < 0 || (s->blocks >> r & 1) || r == o1 || r == o2 || r == o3) return 0;
    char g = ground(s, r);
    if (g == '.' && r != BEAD && r != CROWN) { s->blocks = (s->blocks & ~(1ULL << q)) | (1ULL << r); return 1; }
    if (g == '_' || g == '=') { s->blocks &= ~(1ULL << q); s->filled |= 1ULL << r; return 1; }
    return 0;
}

static void mosto_step(S *s, int d) {
    int q = nb(s->mosto, d);
    if (q < 0 || q == s->moss || q == s->otto) return;
    if (lit(s) >> q & 1) return;
    if (s->blocks >> q & 1) {
        S t = *s;
        if (!push(&t, q, d, s->moss, s->otto, s->mosto)) return;
        t.mosto = q; *s = t; return;
    }
    char g = ground(s, q);
    if (g == '.' || g == '=') s->mosto = q;
}

static void moss_follow(S *s, int d) {
    int q = nb(s->moss, d);
    if (q < 0 || q == s->otto || q == s->mosto || !(lit(s) >> q & 1)) return;
    if (s->blocks >> q & 1) {
        S t = *s;
        if (!push(&t, q, d, s->otto, s->mosto, -1)) return;
        t.moss = q; *s = t; return;
    }
    if (ground(s, q) == '.') s->moss = q;
}

// who: 0 the one the player walks (Moss; Mosto on the other side), 1 Otto. Returns 1 and fills n when the swipe
// changes something.
static int step(const S *s, int who, int d, S *n) {
    *n = *s;
    if (who == 0 && MODE == 3) {
        mosto_step(n, d);
        if (n->mosto == s->mosto) return 0;
        moss_follow(n, MIRROR[d]);
        return 1;
    }
    if (who == 1) {
        if (d != s->face) { n->face = d; return 1; }
        int q = nb(s->otto, d);
        if (q < 0 || q == s->moss || q == s->mosto || (s->blocks >> q & 1) || ground(s, q) != '.') return 0;
        n->otto = q; return 1;
    }
    int q = nb(s->moss, d);
    if (q < 0 || q == s->otto || !(lit(s) >> q & 1)) return 0;
    if (q == s->mosto) {
        if (MODE == 1 && ground(s, q) == '.') { n->moss = q; n->mosto = -1; return 1; }
        return 0;
    }
    if (s->blocks >> q & 1) {
        if (!push(n, q, d, s->otto, s->mosto, -1)) return 0;
        n->moss = q;
    } else {
        if (ground(s, q) != '.') return 0;
        n->moss = q;
    }
    if (n->mosto >= 0) mosto_step(n, MIRROR[d]);
    return memcmp(n, s, sizeof(S)) != 0;
}

static int won(const S *s) {
    if (MODE == 1) return s->mosto < 0;
    if (MODE >= 2) return s->moss == BEAD && s->mosto == CROWN;
    return s->moss == BEAD;
}

// ---- state table ----
static S *st; static int32_t *ht; static size_t htn; static int ns, cap;
static int32_t *eoff, *edst; static int ne, ecap;

static inline uint64_t shash(const S *s) {
    return hmix(s->blocks ^ (s->filled * 0x9E3779B97F4A7C15ULL) ^ ((uint64_t)(uint8_t)s->moss << 0) ^ ((uint64_t)(uint8_t)s->otto << 8) ^ ((uint64_t)(uint8_t)s->face << 16) ^ ((uint64_t)(uint8_t)s->mosto << 24));
}
static int find_or_add(const S *s, int *added) {
    size_t i = shash(s) & (htn - 1);
    while (ht[i] >= 0) {
        if (memcmp(&st[ht[i]], s, sizeof(S)) == 0) { *added = 0; return ht[i]; }
        i = (i + 1) & (htn - 1);
    }
    if (ns >= cap) return -1;
    st[ns] = *s; ht[i] = ns; *added = 1; return ns++;
}

// rows: H strings of W chars joined; returns par (-1 no solution, -2 too large)
// out: path (2 bytes per move: who 'M'/'O', dir 'NESW'), stats[0..7] = states, lost share, hard, turns, pushes, beam, mostomoves
int analyse(const char *rows, int w, int h, int face, int mode, int limit, char *path, double *stats) {
    W = w; H = h; N = w * h; MODE = mode; BEAD = CROWN = -1;
    S s0; memset(&s0, 0, sizeof s0); s0.mosto = -1;
    for (int i = 0; i < N; i++) {
        char c = rows[i];
        G[i] = (c == '_' || c == ' ') ? '_' : c == 'T' ? 'T' : c == '=' ? '=' : '.';
        if (c == 'M') s0.moss = i; if (c == 'O') s0.otto = i; if (c == 'X') s0.mosto = i;
        if (c == '*') BEAD = i; if (c == 'C') CROWN = i; if (c == 'B') s0.blocks |= 1ULL << i;
    }
    s0.face = face;
    lcn = 1 << 18; lccount = 0; lc = calloc(lcn, sizeof(LC));
    cap = limit; st = malloc(sizeof(S) * cap);
    htn = 1; while (htn < (size_t)cap * 2) htn <<= 1;
    ht = malloc(sizeof(int32_t) * htn); memset(ht, -1, sizeof(int32_t) * htn);
    ecap = cap * 8; edst = malloc(sizeof(int32_t) * ecap); eoff = malloc(sizeof(int32_t) * (cap + 1));
    ns = 0; ne = 0;
    int added; find_or_add(&s0, &added);
    int head = 0, overflow = 0;
    while (head < ns) {
        S s = st[head]; eoff[head] = ne;
        for (int who = 0; who < 2 && !overflow; who++) for (int d = 0; d < 4; d++) {
            S n;
            if (!step(&s, who, d, &n)) continue;
            int j = find_or_add(&n, &added);
            if (j < 0 || ne >= ecap) { overflow = 1; break; }
            edst[ne++] = j * 8 + who * 4 + d;
        }
        if (overflow) break;
        head++;
    }
    int result;
    if (overflow) { result = -2; goto done; }
    eoff[ns] = ne;
    // reverse BFS from wins
    {
        int32_t *dist = malloc(sizeof(int32_t) * ns); for (int i = 0; i < ns; i++) dist[i] = -1;
        int32_t *rcnt = calloc(ns + 1, sizeof(int32_t));
        for (int e = 0; e < ne; e++) rcnt[edst[e] / 8 + 1]++;
        for (int i = 0; i < ns; i++) rcnt[i + 1] += rcnt[i];
        int32_t *rsrc = malloc(sizeof(int32_t) * (ne + 1)); int32_t *fill = malloc(sizeof(int32_t) * ns); memcpy(fill, rcnt, sizeof(int32_t) * ns);
        for (int i = 0; i < ns; i++) for (int e = eoff[i]; e < eoff[i + 1]; e++) rsrc[fill[edst[e] / 8]++] = i;
        int32_t *q = malloc(sizeof(int32_t) * ns); int qh = 0, qt = 0;
        for (int i = 0; i < ns; i++) if (won(&st[i])) { dist[i] = 0; q[qt++] = i; }
        while (qh < qt) { int i = q[qh++]; for (int k = rcnt[i]; k < rcnt[i + 1]; k++) { int p = rsrc[k]; if (dist[p] < 0) { dist[p] = dist[i] + 1; q[qt++] = p; } } }
        int lost = 0; for (int i = 0; i < ns; i++) lost += dist[i] < 0;
        stats[0] = ns; stats[1] = (double)lost / ns;
        if (dist[0] < 0) { result = -1; }
        else {
            result = dist[0];
            int cur = 0, k = 0; double hard = 0; int turns = 0, pushes = 0, beam = 0, mm = 0;
            while (dist[cur] > 0) {
                int good = 0, tot = eoff[cur + 1] - eoff[cur], pick = -1;
                for (int e = eoff[cur]; e < eoff[cur + 1]; e++) if (dist[edst[e] / 8] == dist[cur] - 1) { good++; if (pick < 0) pick = e; }
                hard += -log((double)good / tot);
                int nxt = edst[pick] / 8, who = edst[pick] / 4 % 2, d = edst[pick] % 4;
                S *a = &st[cur], *b = &st[nxt];
                if (who == 1 && a->otto == b->otto) turns++;
                if (a->blocks != b->blocks || a->filled != b->filled) pushes++;
                if (who == 0 && a->moss != b->moss) { int ox = a->otto % W, oy = a->otto / W, mx = b->moss % W, my = b->moss / W; if (abs(ox - mx) > 1 || abs(oy - my) > 1) beam++; }
                if (a->mosto >= 0 && b->mosto >= 0 && a->mosto != b->mosto) mm++;
                path[k * 2] = who ? 'O' : (MODE == 3 ? 'X' : 'M'); path[k * 2 + 1] = "NESW"[d]; k++;
                cur = nxt;
            }
            path[k * 2] = 0;
            stats[2] = hard; stats[3] = turns; stats[4] = pushes; stats[5] = beam; stats[6] = mm;
        }
        free(dist); free(rcnt); free(rsrc); free(fill); free(q);
    }
done:
    free(lc); free(st); free(ht); free(edst); free(eoff);
    return result;
}


// ---- simulated players (bounded rationality), for the level search ----
// h: how far the board looks from done, as a player without foresight would judge it (Manhattan distances).
static int md(int a, int b) { return abs(a % W - b % W) + abs(a / W - b / W); }
static int heur(const S *s) {
    if (won(s)) return -1000;
    if (MODE == 1) return s->mosto < 0 ? 0 : md(s->moss, s->mosto);
    if (MODE >= 2) return md(s->moss, BEAD) + md(s->mosto, CROWN);
    return md(s->moss, BEAD);
}
static uint64_t rs;
static inline uint32_t rnd(void) { rs ^= rs << 13; rs ^= rs >> 7; rs ^= rs << 17; return (uint32_t)rs; }

// best value reachable within depth moves (lower is better)
static int look(const S *s, int depth) {
    int best = heur(s);
    if (depth == 0 || best <= -1000) return best;
    for (int who = 0; who < 2; who++) for (int d = 0; d < 4; d++) {
        S n; if (!step(s, who, d, &n)) continue;
        int v = look(&n, depth - 1);
        if (v < best) best = v;
    }
    return best;
}

// Plays like a person who looks `depth` moves ahead, never repeats a position, breaks ties at random.
// Returns the share of `trials` games won within `budget` moves.
double bot(const char *rows, int w, int h, int face, int mode, int depth, int trials, int budget, unsigned seed) {
    W = w; H = h; N = w * h; MODE = mode; BEAD = CROWN = -1;
    S s0; memset(&s0, 0, sizeof s0); s0.mosto = -1;
    for (int i = 0; i < N; i++) {
        char c = rows[i];
        G[i] = (c == '_' || c == ' ') ? '_' : c == 'T' ? 'T' : c == '=' ? '=' : '.';
        if (c == 'M') s0.moss = i; if (c == 'O') s0.otto = i; if (c == 'X') s0.mosto = i;
        if (c == '*') BEAD = i; if (c == 'C') CROWN = i; if (c == 'B') s0.blocks |= 1ULL << i;
    }
    s0.face = face;
    lcn = 1 << 16; lccount = 0; lc = calloc(lcn, sizeof(LC));
    int wins = 0;
    rs = seed * 2654435761u + 1;
    S *seen = malloc(sizeof(S) * (budget + 2));
    for (int t = 0; t < trials; t++) {
        S cur = s0; int ns_ = 0; seen[ns_++] = cur;
        for (int k = 0; k < budget; k++) {
            if (won(&cur)) break;
            S cand[8]; int val[8], nc = 0;
            for (int who = 0; who < 2; who++) for (int d = 0; d < 4; d++) {
                S n; if (!step(&cur, who, d, &n)) continue;
                int rep = 0; for (int j = 0; j < ns_; j++) if (memcmp(&seen[j], &n, sizeof(S)) == 0) { rep = 1; break; }
                if (rep) continue;
                cand[nc] = n; val[nc] = look(&n, depth - 1); nc++;
            }
            if (!nc) break;
            int best = val[0]; for (int i = 1; i < nc; i++) if (val[i] < best) best = val[i];
            int pick[8], np = 0; for (int i = 0; i < nc; i++) if (val[i] == best) pick[np++] = i;
            cur = cand[pick[rnd() % np]];
            seen[ns_++] = cur;
        }
        if (won(&cur)) wins++;
    }
    free(seen); free(lc);
    return (double)wins / trials;
}
