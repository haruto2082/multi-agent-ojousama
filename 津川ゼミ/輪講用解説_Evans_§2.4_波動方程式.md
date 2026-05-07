# 輪講用解説 — Evans『PDE』§2.4 WAVE EQUATION (pp.65–73)

- **教科書**: Lawrence C. Evans, *Partial Differential Equations*, AMS Graduate Studies in Mathematics, Vol.19 (2nd ed.)
- **対象範囲**: §2.4 WAVE EQUATION (pp.65 末尾 〜 p.73)
- **写真ファイル**: `converted/IMG_3890.jpg` 〜 `IMG_3898.jpg` (9 枚, p.65–73 に対応)
- **作成目的**: 津川ゼミ輪講での発表資料。各ページの式・主張をテキスト本文とそのまま対応付けながら、行間補完と直感的説明を加える。

---

## 0. この章の物語 (1 分で読み切るロードマップ)

§2.4 のゴールは、$n$ 次元波動方程式

$$u_{tt} - \Delta u = 0 \qquad (x\in\mathbb R^n,\ t>0)$$

の初期値問題を**明示公式**で解くことです。$n$ ごとに公式が異なるので、Evans は次の戦略をとります。

```
[n=1]  d'Alembert 公式  ──── 因数分解で素直に解ける
                                 ↑ これを土台に高次元へ持ち上げる
[n≥2]  球面平均 U(x;r,t) を取る
        ↓
       Euler–Poisson–Darboux (EPD) 方程式  ←── r と t だけの 1+1 次元 PDE
        ↓ ([n=3] は Ũ:=rU で 1 次元波動方程式へ)
        ↓ ([n=2] は降下法 — 一段上の n=3 に埋め込む)
       d'Alembert 公式へ帰着
        ↓ r→0+ で逆変換
[n=3]  Kirchhoff 公式
[n=2]  Poisson 公式
```

> **キーワード**: 因数分解 / 進行波 / 反射法 / 球面平均 / EPD 方程式 / Kirchhoff 公式 / Huygens 強原理 / 降下法。

---

## 1. p.65 末尾 — §2.4 への橋渡し (画像 IMG_3890)

### 1.1 §2.3 補題証明の終わり (式 46–48)

p.65 上半分は §2.3 (熱方程式) の最大値原理に絡む補題の証明末尾です。要点だけ拾います。

- 式 (46): $\ddot e(t)\,e(t) \ge \dot e(t)^2$ ($0\le t\le T$)
- 式 (47): $e(t)>0$ on $[t_1,t_2]$ を仮定
- 式 (48): $f(t):=\log e(t)$ とおくと、$\ddot f(t)=\dfrac{\ddot e}{e} - \dfrac{\dot e^2}{e^2}\ge 0$ (式 46 から)

つまり $\log e$ が**凸**。Jensen の不等式から
$$e\bigl((1-\tau)t_1+\tau t_2\bigr)\le e(t_1)^{1-\tau}\,e(t_2)^{\tau}\qquad (0<\tau<1)$$
を得て、これと矛盾を作って §2.3 の補題を閉じる、というのが p.65 上半分の中身です。

> **記号 $\square$**: 段落末右下の四角は **Q.E.D. (証明終)**。Halmos symbol / tombstone とも呼びます。

### 1.2 §2.4 の開始 (p.65 下半分)

ここから §2.4 が始まります。本文の言い回しを引きながら確認します。

> *"In this section we investigate the wave equation*
> $$u_{tt} - \Delta u = 0 \tag{1}$$
> *and the nonhomogeneous wave equation*
> $$u_{tt} - \Delta u = f, \tag{2}$$
> *subject to appropriate initial and boundary conditions. Here $t>0$ and $x\in U$, where $U\subset\mathbb R^n$ is open."*

- (1): **斉次** (homogeneous) 波動方程式
- (2): **非斉次** (nonhomogeneous) 波動方程式 — 強制項 $f(x,t)$ あり
- 未知関数 $u:\bar U\times[0,\infty)\to\mathbb R$、既知関数 $f:U\times[0,\infty)\to\mathbb R$
- ラプラシアン $\Delta$ は**空間変数 $x=(x_1,\dots,x_n)$ について**:
  $$\Delta u = \sum_{i=1}^n u_{x_ix_i}$$

> **「時間 2 階微分 $u_{tt}$ から空間ラプラシアン $\Delta u$ を引いて 0」** が核。$\Delta u$ は「周辺の平均との差」を測るので、(1) は「周りより低ければ加速して上がる、高ければ加速して下がる」という弦の復元力のイメージで読めます。

---

## 2. p.66 — 物理的解釈と方程式の素性 (画像 IMG_3891)

### 2.1 ダランベルシアン略記

> *"A common abbreviation is to write*
> $$\Box u = u_{tt} - \Delta u."$$

これが **d'Alembertian / wave operator** $\Box$。本文中の $\Box$ は囲み記号ではなくこの**演算子**です。

### 2.2 解の素性に関する宣言

> *"We shall discover that solutions of the wave equation behave quite differently than solutions of Laplace's equation or the heat equation. For example, these solutions are generally not $C^\infty$, exhibit finite speed of propagation, etc."*

ポイント:

- **滑らかにしない**: 熱方程式は $C^\infty$ にしてしまうが、波動方程式は初期データの滑らかさをそのまま (あるいは劣化させて) 運ぶ。
- **有限伝播速度**: 影響は光円錐 $|y-x|\le t$ の中にしか伝わらない。
- これらは後で **Theorem 1 の Remark (ii)** や **Kirchhoff 公式の球面サポート** として具体化される。

### 2.3 物理的意味 (Physical interpretation)

| $n$ | 現象 | $u(x,t)$ の意味 |
|---|---|---|
| 1 | 振動弦 (vibrating string) | 弦の鉛直変位 |
| 2 | 太鼓の膜 (membrane) | 膜の鉛直変位 |
| 3 | 弾性固体 (elastic solid) | 点 $x$ における変位の 1 成分 |

### 2.4 Newton 第二法則からの導出

任意の滑らかな部分領域 $V\subset U$ をとり、質量密度を $1$ と規格化します。

- **加速度の体積積分** (= 「質量×加速度」):
  $$\dfrac{d^2}{dt^2}\int_V u\,dx = \int_V u_{tt}\,dx$$
- **境界 $\partial V$ を通って $V$ に入る正味の接触力**:
  $$-\int_{\partial V}\mathbf F\cdot\nu\,dS$$
  ($\nu$ は外向き単位法線、$\mathbf F$ は内部応力場)

Newton 第二法則 (= 力 = 質量×加速度) を当て、発散定理を使うと
$$\int_V u_{tt}\,dx = -\int_{\partial V}\mathbf F\cdot\nu\,dS = -\int_V \operatorname{div}\mathbf F\,dx.$$
$V$ は任意なので積分記号を外し、
$$u_{tt} + \operatorname{div}\mathbf F(Du) = 0.$$

弾性体では $\mathbf F$ は変位勾配 $Du$ の関数です。**小変形の線形化** で
$$\mathbf F(Du)\approx -a\,Du \quad\Rightarrow\quad u_{tt} - a\,\Delta u = 0.$$
$a=1$ が**波動方程式**。

> **コメント**: $\Delta u = \operatorname{div}(Du)$ なので、弾性的な復元力の発散がそのままラプラシアンとして出てくる、というのが幾何学的な気持ち。

### 2.5 自然な初期条件は 2 つ

最後の段落:

> *"This physical interpretation strongly suggests it will be mathematically appropriate to specify two initial conditions, on the displacement $u$ and the velocity $u_t$, at time $t=0$."*

時間 2 階の方程式なので、初期条件は**位置 $u(\cdot,0)=g$ と速度 $u_t(\cdot,0)=h$ の 2 つ**を与えるのが自然。

---

## 3. p.67 — §2.4.1.a 1 次元の d'Alembert 公式 (画像 IMG_3892)

### 3.1 §2.4.1 の戦略宣言

> *"§2.4.1 Solution by spherical means. We began §§2.2.1 and 2.3.1 by searching for certain scaling invariant solutions of Laplace's equation and the heat equation. For the wave equation however we will instead present the (reasonably) elegant method of solving (1) first for $n=1$ directly and then for $n\ge 2$ by the method of spherical means."*

> **読み方**: §2.2 (Laplace) と §2.3 (Heat) ではスケール不変解 (基本解) を探したが、§2.4 ではアプローチを変えて、まず $n=1$ をそのまま解き、$n\ge 2$ は**球面平均法**で $n=1$ に帰着する、という方針。

### 3.2 1 次元の初期値問題 (式 3)

$$\begin{cases}u_{tt}-u_{xx}=0 & \text{in }\mathbb R\times(0,\infty)\\ u=g,\ u_t=h & \text{on }\mathbb R\times\{t=0\}\end{cases}\tag{3}$$

### 3.3 因数分解のアイデア (式 4)

> *"Let us first note the PDE in (3) can be 'factored,' to read*
> $$\Bigl(\tfrac{\partial}{\partial t}+\tfrac{\partial}{\partial x}\Bigr)\Bigl(\tfrac{\partial}{\partial t}-\tfrac{\partial}{\partial x}\Bigr)u = u_{tt}-u_{xx}=0."$$

これは形式的計算で確認できます:
$$\bigl(\partial_t+\partial_x\bigr)\bigl(\partial_t-\partial_x\bigr)u = u_{tt}-u_{tx}+u_{xt}-u_{xx} = u_{tt}-u_{xx}.$$
$C^2$ なので $u_{tx}=u_{xt}$ で中央項が打ち消されます。

> **重要**: この因数分解は $n=1$ でしかうまくいきません。$n\ge 2$ では $u_{tt}-\Delta u$ を 1 階作用素 2 個に分けることはできない (これが球面平均法を必要とする理由)。

### 3.4 補助関数 $v$ の導入 (式 5)

> *Write*
> $$v(x,t):=\Bigl(\tfrac{\partial}{\partial t}-\tfrac{\partial}{\partial x}\Bigr)u(x,t). \tag{5}$$

つまり $v=u_t-u_x$。式 (4) によって
$$v_t(x,t)+v_x(x,t)=0\qquad (x\in\mathbb R,\,t>0).$$

これは**定数係数の輸送方程式 (transport equation)** ($n=1,\,b=1$)。§2.1.1 の結果から特性線 $x-t=$const に沿って $v$ は一定:
$$v(x,t) = a(x-t),\tag{6}$$
ただし $a(x):=v(x,0)=h(x)-g'(x)$ ($u_t(x,0)=h$, $u_x(x,0)=g'$ なので)。

### 3.5 非斉次輸送方程式に帰着 (式 7)

(5) より $u_t(x,t)-u_x(x,t)=a(x-t)$ — **右辺のある輸送方程式** ($n=1,\,b=-1,\,f(x,t)=a(x-t)$)。§2.1.2 の公式 (5) (非斉次輸送方程式の解の積分表示) を当てて

> *"Applying formula (5) from §2.1.2 (with $n=1,\ b=-1,\ f(x,t)=a(x-t)$) implies*
> $$u(x,t)=\int_0^t a\bigl(x+(t-s)-s\bigr)\,ds + b(x+t),$$
> *where we have $b(x):=u(x,0)$. Then*
> $$u(x,t)=\tfrac12\int_{x-t}^{x+t} a(y)\,dy + b(x+t).\tag{7}"$$

> **解説**: 第 1 項は変数変換 $y=x+t-2s$ ($dy=-2\,ds$) によって $\int_0^t a(x+t-2s)\,ds = \tfrac12\int_{x-t}^{x+t} a(y)\,dy$ となります。$b(x+t)$ は同次部分の解 (左進行波)。

---

## 4. p.68 — d'Alembert 公式の完成と Theorem 1 (画像 IMG_3893)

### 4.1 初期データの代入 (本文 p.68 上)

> *"where we have $b(x):=u(x,0)$. We lastly invoke the initial conditions in (3) to compute $a$ and $b$. The first initial condition in (3) gives*
> $$b(x)=g(x)\quad (x\in\mathbb R);$$
> *whereas the second initial condition and (5) imply*
> $$a(x)=v(x,0)=u_t(x,0)-u_x(x,0)=h(x)-g'(x)\quad (x\in\mathbb R)."$$

(7) に代入して整理:
$$u(x,t) = \tfrac12 \int_{x-t}^{x+t}\bigl[h(y)-g'(y)\bigr]\,dy + g(x+t).$$
$\int g'(y)\,dy = g(x+t)-g(x-t)$ を使い、$g(x+t)$ と打ち消し&足し合わせると

### 4.2 d'Alembert 公式 (式 8)

$$\boxed{\,u(x,t)=\tfrac12\bigl[g(x+t)+g(x-t)\bigr]+\tfrac12\int_{x-t}^{x+t}h(y)\,dy\quad (x\in\mathbb R,\,t\ge 0)\,}\tag{8}$$

これが **d'Alembert 公式 (1747)**。1 次元の波動方程式の初期値問題の**完全に閉じた解の公式**です。

### 4.3 Theorem 1 (1 次元の解の存在)

> **Theorem 1 (Solution of wave equation, $n=1$).** *Assume $g\in C^2(\mathbb R)$, $h\in C^1(\mathbb R)$, and define $u$ by d'Alembert's formula (8). Then*
> *(i) $u\in C^2(\mathbb R\times[0,\infty))$,*
> *(ii) $u_{tt}-u_{xx}=0$ in $\mathbb R\times(0,\infty)$,*
> *(iii) $\displaystyle\lim_{(x,t)\to(x^0,0),\,t>0} u(x,t)=g(x^0)$, $\lim u_t(x,t)=h(x^0)$ (各 $x^0\in\mathbb R$).*

「証明は単なる代入計算 (a straightforward calculation)」 — (8) を直接 $u_{tt}-u_{xx}$ に入れて 0、$t\to 0$ の極限で $g,h$ を再現することを確認するだけです。

### 4.4 Remarks (重要な定性的観察)

**Remark (i) — 一般解は進行波 2 本の和**:

> *"In view of (8), our solution $u$ has the form*
> $$u(x,t)=F(x+t)+G(x-t)$$
> *for appropriate functions $F$ and $G$. Conversely any function of this form solves $u_{tt}-u_{xx}=0$. Hence the general solution of the one-dimensional wave equation is a sum of the general solution of $u_t - u_x = 0$ and the general solution of $u_t + u_x = 0$. This is a consequence of the factorization (4)."*

直感: $F(x+t)$ は **左進行波** (時間が経つと $x$ が小さい方へ動く)、$G(x-t)$ は **右進行波**。因数分解で $(\partial_t+\partial_x)u=0$ と $(\partial_t-\partial_x)u=0$ の 2 系統に分解されたことの直接的帰結。

**Remark (ii) — 滑らかさの保存則** (画像 IMG_3894 上):

> *"We see from (8) that if $g\in C^k$ and $h\in C^{k-1}$, then $u\in C^k$, but is not in general smoother. Thus the wave equation does not cause instantaneous smoothing of the initial data, as does the heat equation."*

熱方程式 ($t>0$ で $C^\infty$) との対比。波動方程式は **滑らかさを増やさない** = 特異性は伝播する = 有限伝播速度の数学的帰結。

---

## 5. p.69 — 反射法 (Reflection method) (画像 IMG_3894)

### 5.1 半直線上の問題 (式 9)

> *"A reflection method. To illustrate a further application of d'Alembert's formula, let us next consider this initial/boundary-value problem on the half-line $\mathbb R_+ = \{x>0\}$:*
> $$\begin{cases}u_{tt}-u_{xx}=0 & \text{in }\mathbb R_+\times(0,\infty)\\ u=g,\ u_t=h & \text{on }\mathbb R_+\times\{t=0\}\\ u=0 & \text{on }\{x=0\}\times(0,\infty),\end{cases}\tag{9}$$
> *where $g,h$ are given, with $g(0)=h(0)=0$."*

両立条件 $g(0)=h(0)=0$ は、$x=0$ での Dirichlet 境界 $u=0$ と初期条件の両立から要請されます。

### 5.2 奇拡張 (本文 p.69 中段)

> *"We convert (9) into the form (3) by extending $u,g,h$ to all of $\mathbb R$ by odd reflection. That is, we set*
> $$\tilde u(x,t):=\begin{cases}u(x,t) & x\ge 0,\,t\ge 0\\ -u(-x,t) & x\le 0,\,t\ge 0\end{cases}$$
> $$\tilde g(x):=\begin{cases}g(x) & x\ge 0\\ -g(-x) & x\le 0\end{cases}\quad \tilde h(x):=\begin{cases}h(x) & x\ge 0\\ -h(-x) & x\le 0\end{cases}"$$

奇拡張すると $\tilde u(0,t)\equiv 0$ が**自動的に**成り立ちます (奇関数の原点値はゼロ)。

> **なぜ奇か?**: 偶拡張だと境界値が一般に 0 にならず Dirichlet を破る。奇拡張なら原点で常に 0 でつじつまが合う。

### 5.3 全空間問題への帰着と d'Alembert 公式

奇拡張した $\tilde u$ は $\mathbb R\times(0,\infty)$ 全体で $\tilde u_{tt}=\tilde u_{xx}$ を満たし (奇関数性は方程式と整合)、初期データ $\tilde g,\tilde h$ で d'Alembert 公式 (8) を適用できます。

$x\ge 0$ に制限して整理 (式 10):
$$u(x,t)=\begin{cases}\tfrac12\bigl[g(x+t)+g(x-t)\bigr]+\tfrac12\int_{x-t}^{x+t}h(y)\,dy & x\ge t\ge 0\\[4pt]\tfrac12\bigl[g(x+t)-g(t-x)\bigr]+\tfrac12\int_{-x+t}^{x+t}h(y)\,dy & 0\le x\le t\end{cases}\tag{10}$$

> **領域分け**:
> - $x\ge t$ の領域 = まだ壁の影響が届いていない = 全空間と同じ d'Alembert 公式
> - $0\le x\le t$ の領域 = 壁からの反射波が届いた領域 = $g(x-t)$ が $-g(t-x)$ にひっくり返る (符号反転 + 引数反転)

### 5.4 物理的解釈

> *"If $h\equiv 0$, we can understand formula (10) as saying that an initial displacement $g$ splits into two parts, one moving to the right with speed one and the other to the left with speed one. The latter then reflects off the point $x=0$, where the vibrating string is held fixed."*

つまり「**初期形が左右半々に分かれて伝播し、左進行成分は壁で反射して符号反転して戻る**」。実験的にもよく知られた振る舞いを公式が再現しています。

---

## 6. p.70 — §2.4.1.b 球面平均と EPD 方程式 (画像 IMG_3895)

ここから $n\ge 2$ の本論に入ります。

### 6.1 高次元初期値問題 (式 11)

$n\ge 2$, $m\ge 2$、$u\in C^m(\mathbb R^n\times[0,\infty))$ が
$$\begin{cases}u_{tt}-\Delta u=0 & \text{in }\mathbb R^n\times(0,\infty)\\ u=g,\ u_t=h & \text{on }\mathbb R^n\times\{t=0\}\end{cases}\tag{11}$$
を解くと**仮定**します ($u$ の存在を一旦認めて公式を導出 → 後でその公式が実際に解になっていると検証する流れ)。

### 6.2 戦略宣言

> *"We intend to derive an explicit formula for $u$ in terms of $g,h$. The plan will be to study first the average of $u$ over certain spheres. These averages, taken as functions of the time $t$ and the radius $r$, turn out to solve the Euler–Poisson–Darboux equation, a PDE which we can for odd $n$ convert into the ordinary one-dimensional wave equation. Applying d'Alembert's formula, or more precisely its variant (10), eventually leads us to a formula for the solution."*

**戦略の 4 段階**:
1. 球面平均 $U(x;r,t)$ を考える
2. $U$ が EPD 方程式を満たすことを示す
3. 適切な変換で $U$ を 1 次元波動方程式に帰着
4. d'Alembert (or 反射法 (10)) で解く → 逆変換

### 6.3 球面平均の定義 (式 12, 13)

固定 $x\in\mathbb R^n$, $t>0$, $r>0$ に対し:

$$U(x;r,t):=\fint_{\partial B(x,r)} u(y,t)\,dS(y) \tag{12}$$

$$G(x;r):=\fint_{\partial B(x,r)} g(y)\,dS(y),\quad H(x;r):=\fint_{\partial B(x,r)} h(y)\,dS(y) \tag{13}$$

> **記号 $\fint_E$**: 平均積分 (mean integral) $\fint_E f := \dfrac{1}{|E|}\int_E f$。「バー付き積分記号」と呼ぶことも。
> **記号 $\partial B(x,r)$**: 中心 $x$, 半径 $r$ の球の**境界 (球面)**。$B(x,r)$ は球そのもの。
> **記号 $dS,\,dS(y)$**: 球面上の表面測度 ($n=3$ なら 2 次元面積要素)。

「点 $x$ を中心とする半径 $r$ の球面上での $u$ の平均値」を $r$ と $t$ の 2 変数関数として捉え直すのがポイント。

### 6.4 Lemma 1 (Euler–Poisson–Darboux 方程式) (式 14)

> **LEMMA 1 (Euler–Poisson–Darboux equation).** *Fix $x\in\mathbb R^n$, and let $u\in C^m(\mathbb R^n\times[0,\infty))$ satisfy (11). Then $U\in C^m(\mathbb R_+\times[0,\infty))$ and*
> $$\begin{cases}U_{tt}-U_{rr}-\dfrac{n-1}{r}U_r=0 & \text{in }\mathbb R_+\times(0,\infty)\\ U=G,\ U_t=H & \text{on }\mathbb R_+\times\{t=0\}.\end{cases}\tag{14}$$

> **The partial differential equation in (14) is the Euler–Poisson–Darboux equation. (Note that the term $\frac{n-1}{r}U_r$ is the radial part of the Laplacian $\Delta$ in polar coordinates.)**

**直感**: 極座標表示でラプラシアンを動径成分と球面成分に分けると、動径部分は
$$\Delta_{\rm rad} = \partial_r^2 + \dfrac{n-1}{r}\partial_r.$$
球面平均は球面方向 (角度方向) を平均で潰してしまうので、**動径方向の波動方程式風 PDE** だけが残る — それが EPD 方程式。

---

## 7. p.71 — Lemma 1 の証明 と $n=3,2$ への準備 (画像 IMG_3896)

### 7.1 EPD 方程式の証明 (Step 1, 式 15–16)

> *"Proof. 1. As in the proof of Theorem 2 in §2.2.2 we compute for $r>0$*
> $$U_r(x;r,t)=\dfrac{r}{n}\fint_{B(x,r)}\Delta u(y,t)\,dy.\tag{15}$$
> *From this equality we deduce $\lim_{r\to 0+}U_r(x;r,t)=0$. We next differentiate (15), to discover after some computations that*
> $$U_{rr}(x;r,t)=\fint_{\partial B(x,r)}\Delta u\,dS+\Bigl(\tfrac1n-1\Bigr)\fint_{B(x,r)}\Delta u\,dy.\tag{16}$$
> *Thus $\lim_{r\to 0+}U_{rr}(x;r,t)=\tfrac1n\Delta u(x,t)$. Using formula (16) we can similarly compute $U_{rrr}$, etc., and so verify that $U\in C^m(\mathbb R_+\times[0,\infty))$."*

> **要点**:
> - 式 (15) は §2.2.2 (調和関数の球面平均) で出てきた**球面平均の動径微分公式**。発散定理から
>   $$\dfrac{d}{dr}\fint_{\partial B(x,r)} u\,dS = \dfrac{r}{n}\fint_{B(x,r)}\Delta u\,dy$$
>   が出る (これは PDE 教科書の頻出補題)。
> - 式 (16) はその両辺をさらに $r$ で微分した結果。導出は表面測度・体積測度のスケーリング ($r^{n-1}$ と $r^n$) に注意して微分計算するだけだが、Evans は "after some computations" で済ませている。

### 7.2 EPD 方程式の証明 (Step 2 — 本題)

(15) で $\Delta u = u_{tt}$ ((11) より) と置換して $r^{n-1}$ を掛け、$r$ で微分:
$$U_r = \dfrac{r}{n}\fint_{B(x,r)} u_{tt}\,dy = \dfrac{1}{n\alpha(n)}\cdot\dfrac{1}{r^{n-1}}\int_{B(x,r)} u_{tt}\,dy.$$
両辺に $r^{n-1}$ を掛けて
$$r^{n-1}U_r = \dfrac{1}{n\alpha(n)}\int_{B(x,r)} u_{tt}\,dy.$$
両辺を $r$ で微分すると、右辺は球内積分の動径微分 = 表面積分 (体積要素 $dr$ 分):
$$\bigl(r^{n-1}U_r\bigr)_r = \dfrac{1}{n\alpha(n)}\int_{\partial B(x,r)} u_{tt}\,dS = r^{n-1}\fint_{\partial B(x,r)} u_{tt}\,dS = r^{n-1}U_{tt}.$$

ここで $\alpha(n)$ は単位球の体積、$n\alpha(n)$ は単位球面の表面積です。左辺を Leibniz で展開:
$$r^{n-1}U_{rr}+(n-1)r^{n-2}U_r = r^{n-1}U_{tt}.$$
両辺を $r^{n-1}$ で割って
$$U_{tt}=U_{rr}+\dfrac{n-1}{r}U_r,$$
これが式 (14) の本体です。$\blacksquare$

### 7.3 §2.4.1.c の方針宣言

> *"c. Solution for $n=3,2$, Kirchhoff's and Poisson's formulas. The overall plan in the ensuing subsections will be to transform the Euler–Poisson–Darboux equation (14) into the usual one-dimensional wave equation. As the full procedure is rather complicated, we pause here to handle the simpler cases $n=3,2$, in that order."*

**戦略**:
- $n=3$: $\tilde U:=rU$ という単純な掛け算で $\tilde U_{tt}=\tilde U_{rr}$ になる (奇跡的に係数が合う)
- $n=2$: その手は使えない → **降下法 (method of descent)**: $n=2$ の問題を $x_3$ に依存しない $n=3$ の問題と見なして、$n=3$ の Kirchhoff 公式から逆算する

### 7.4 $n=3$ の出発点 (式 17)

> *"Solution for $n=3$. Let us therefore hereafter take $n=3$, and suppose $u\in C^2(\mathbb R^3\times[0,\infty))$ solves the initial-value problem (11). We recall the definitions (12), (13) of $U,G,H$, and then set*
> $$\tilde U:=rU. \tag{17}$$"

---

## 8. p.72 — $n=3$ の解と Kirchhoff 公式の導出 (画像 IMG_3897)

### 8.1 補助関数 (式 18) と $\tilde U$ が満たす方程式 (式 19)

$$\tilde G:=rG,\quad \tilde H:=rH \tag{18}$$

主張: $\tilde U$ は次の半直線問題を解く。
$$\begin{cases}\tilde U_{tt}-\tilde U_{rr}=0 & \text{in }\mathbb R_+\times(0,\infty)\\ \tilde U=\tilde G,\ \tilde U_t=\tilde H & \text{on }\mathbb R_+\times\{t=0\}\\ \tilde U=0 & \text{on }\{r=0\}\times(0,\infty)\end{cases}\tag{19}$$

**検証** (本文 p.72 上):

> *"Indeed*
> $$\tilde U_{tt}=rU_{tt}=r\Bigl[U_{rr}+\dfrac{2}{r}U_r\Bigr]\quad \text{by (14), with }n=3$$
> $$=rU_{rr}+2U_r=(U+rU_r)_r=\tilde U_{rr}."$$

ステップを丁寧に書くと:
1. $\tilde U=rU$ なので $\tilde U_{tt} = rU_{tt}$。
2. (14) の $n=3$ 版から $U_{tt}=U_{rr}+\dfrac{2}{r}U_r$。
3. これを掛けて $\tilde U_{tt} = rU_{rr}+2U_r$。
4. 一方 $\tilde U_r = U + rU_r$ (積の微分)、$\tilde U_{rr} = U_r + U_r + rU_{rr} = 2U_r + rU_{rr}$。
5. よって $\tilde U_{tt}=\tilde U_{rr}$。

> **「奇跡」のからくり**: $rU_{rr}+2U_r = (rU)_{rr}$ という Leibniz 展開が成り立つのは、係数 $2$ が「微分回数 1 階 × 因子 $r$」に対応するため。これは EPD の係数 $n-1=2$ ($n=3$) のときだけ等しくなる関係。$n=2$ では $n-1=1$ でずれてしまうので $\tilde U=rU$ は使えない (= 降下法が必要になる)。

### 8.2 反射法 (式 10) を (19) に適用 → 式 (20)

(19) は §5 の半直線 Dirichlet 問題と同じ形なので、$0\le r\le t$ で式 (10) の下側 (反射波が届いた領域) を使い:
$$\tilde U(x;r,t)=\tfrac12\bigl[\tilde G(r+t)-\tilde G(t-r)\bigr]+\tfrac12\int_{-r+t}^{r+t}\tilde H(y)\,dy. \tag{20}$$

### 8.3 元の関数 $u$ への復元

(12) より $u(x,t)=\lim_{r\to 0+} U(x;r,t)$。$U=\tilde U/r$ なので
$$u(x,t)=\lim_{r\to 0+}\dfrac{\tilde U(x;r,t)}{r}=\lim_{r\to 0+}\Bigl[\dfrac{\tilde G(t+r)-\tilde G(t-r)}{2r}+\dfrac{1}{2r}\int_{t-r}^{t+r}\tilde H(y)\,dy\Bigr].$$

- 第 1 項 → $\tilde G'(t)$ (中心差分の極限 = 微分の定義そのもの)
- 第 2 項 → $\tilde H(t)$ (積分の平均値の定理)

よって
$$u(x,t)=\tilde G'(t)+\tilde H(t).$$

### 8.4 球面平均で書き換え (式 21)

(13)(18) より $\tilde G(t)=tG(x;t)=t\fint_{\partial B(x,t)}g\,dS$, 同様に $\tilde H(t)=t\fint_{\partial B(x,t)}h\,dS$。$\tilde H(t)$ をそのまま、$\tilde G'(t)$ は $\partial_t$ に置換して

$$u(x,t)=\dfrac{\partial}{\partial t}\Bigl(t\fint_{\partial B(x,t)} g\,dS\Bigr) + t\fint_{\partial B(x,t)} h\,dS \tag{21}$$

### 8.5 中心 $x$, 半径 $t$ の球面 → 単位球面への置換

p.72 下:

> *"But*
> $$\fint_{\partial B(x,t)} g(y)\,dS(y) = \fint_{\partial B(0,1)} g(x+tz)\,dS(z);$$
> *and so*
> $$\dfrac{\partial}{\partial t}\Bigl(\fint_{\partial B(x,t)} g\,dS\Bigr) = \fint_{\partial B(0,1)} Dg(x+tz)\cdot z\,dS(z) = \fint_{\partial B(x,t)} Dg(y)\cdot\dfrac{y-x}{t}\,dS(y)."$$

> **記号 $Dg$**: 勾配 (gradient)。$Dg=(g_{x_1},\dots,g_{x_n})$。Evans は $\nabla$ より $D$ を多用。
> **記号 $\cdot$**: 内積。

ここでの計算は $z=(y-x)/t$ という変数変換 (球面測度のスケール変換 $dS(y) = t^{n-1}\,dS(z)$ と平均の正規化 $|\partial B(x,t)|=t^{n-1}|\partial B(0,1)|$ がちょうど打ち消す) と、合成関数の微分 $\partial_t g(x+tz) = Dg(x+tz)\cdot z$ から従います。

---

## 9. p.73 — Kirchhoff 公式 / $n=2$ 降下法 (画像 IMG_3898)

### 9.1 Kirchhoff 公式 (式 22)

(21) に上の置換結果を代入し、$\partial_t (t\,\bar g_t) = \bar g_t + t\,\partial_t \bar g_t$ ($\bar g_t := \fint_{\partial B(x,t)} g\,dS$) を Leibniz で展開すると、最終的に

$$\boxed{\,u(x,t)=\fint_{\partial B(x,t)}\bigl[t\,h(y)+g(y)+Dg(y)\cdot(y-x)\bigr]\,dS(y) \quad (x\in\mathbb R^3,\,t>0)\,}\tag{22}$$

> *"This is Kirchhoff's formula for the solution of the initial-value problem (11) in three dimensions."*

**読み方**:
- 解 $u(x,t)$ は **球面 $\partial B(x,t)$ 上の積分のみ** で書かれる (球の内部は不要)
- 第 1 項 $t\,h$: 初速分布の球面平均
- 第 2 項 $g$: 初期形そのものの球面平均
- 第 3 項 $Dg\cdot(y-x)$: 初期形の勾配と動径ベクトルの内積 — 「波の押し出し」効果
- → **Huygens 強原理**: 3 次元では波は球殻として伝播し、後ろを残さない (音や光がはっきり結像する物理的根拠)
- → 因果律 / 光円錐: 初期データの値は「ちょうど距離 $t$ の点」でだけ効く

### 9.2 $n=2$ — 降下法 (method of descent)

> *"Solution for $n=2$. No transformation like (17) works to convert the Euler–Poisson–Darboux equation into the one-dimensional wave equation when $n=2$. Instead we will take the initial-value problem (11) for $n=2$ and simply regard it as a problem for $n=3$, in which the third spatial variable $x_3$ does not appear."*

> *"Indeed, assuming $u\in C^2(\mathbb R^2\times[0,\infty))$ solves (11) for $n=2$, let us write*
> $$\bar u(x_1,x_2,x_3,t):=u(x_1,x_2,t).\tag{23}"$$

**手順**:
1. $n=2$ の解 $u$ を $x_3$ 方向に **定数として** 拡張して $\bar u$ を作る (式 23)。
2. $\bar u$ は 3 次元の波動方程式を満たす (式 24):
   $$\begin{cases}\bar u_{tt}-\Delta\bar u=0 & \text{in }\mathbb R^3\times(0,\infty)\\ \bar u=\bar g,\ \bar u_t=\bar h & \text{on }\mathbb R^3\times\{t=0\}\end{cases}\tag{24}$$
   ただし $\bar g(x_1,x_2,x_3):=g(x_1,x_2)$, $\bar h(x_1,x_2,x_3):=h(x_1,x_2)$ ($x_3$ について定数)。
3. Kirchhoff 公式 (式 21) を $\bar u$ に適用 (式 25):
   $$u(x,t)=\bar u(\bar x,t)=\dfrac{\partial}{\partial t}\Bigl(t\fint_{\partial \bar B(\bar x,t)}\bar g\,d\bar S\Bigr)+t\fint_{\partial \bar B(\bar x,t)}\bar h\,d\bar S\tag{25}$$
   ここで $x=(x_1,x_2)\in\mathbb R^2$, $\bar x=(x_1,x_2,0)\in\mathbb R^3$, $\bar B(\bar x,t)$ は $\mathbb R^3$ の球。

> **記号 $\bar u,\bar g,\bar h,\bar x,\bar B,d\bar S$**: bar (上線) は **3 次元への拡張版** を表す Evans の慣習。**複素共役ではない**。

### 9.3 $\mathbb R^3$ 球面積分の $\mathbb R^2$ 円板への落とし込み

$\bar u$ は $x_3$ に依存しないので、$\partial \bar B(\bar x,t)$ は **上下 2 つの半球** に分けられ、それぞれを $\mathbb R^2$ の円板 $B(x,t)$ に投影できます。グラフ表示
$$x_3 = \pm\gamma(y),\quad \gamma(y):=(t^2-|y-x|^2)^{1/2},\quad y\in B(x,t)$$
の表面積要素は $dS = \sqrt{1+|D\gamma(y)|^2}\,dy$。本文:

> *"$\fint_{\partial \bar B(\bar x,t)} \bar g\,d\bar S = \dfrac{1}{4\pi t^2}\int_{\partial \bar B(\bar x,t)}\bar g\,d\bar S = \dfrac{2}{4\pi t^2}\int_{B(x,t)} g(y)\bigl(1+|D\gamma(y)|^2\bigr)^{1/2}\,dy,$*
> *where $\gamma(y)=(t^2-|y-x|^2)^{1/2}$ for $y\in B(x,t)$. The factor "2" enters since $\partial \bar B(\bar x,t)$ consists of two hemispheres."*

- $4\pi t^2$ は $\mathbb R^3$ の半径 $t$ 球の表面積
- factor $2$: 上下半球の両方分
- 後で $1+|D\gamma|^2 = t^2/(t^2-|y-x|^2)$ から $\sqrt{1+|D\gamma|^2}=t/\sqrt{t^2-|y-x|^2}$ になり、Poisson 公式 (本文 p.74 で完成) の特徴的な分母に化ける。

### 9.4 (続き = p.74) Poisson 公式 — 補足

写真は p.73 で切れているので、続きを補っておきます。最終的に

$$\boxed{\,u(x,t)=\dfrac12\fint_{B(x,t)}\dfrac{t\,g(y)+t^2\,h(y)+t\,Dg(y)\cdot(y-x)}{\sqrt{t^2-|y-x|^2}}\,dy\quad (x\in\mathbb R^2,\,t>0)\,}$$

これが **Poisson 公式 (n=2)**。3 次元と異なり**球の内部全体で積分**する (= 波が後ろを引きずる = Huygens 弱原理)。

> **物理的含意**: 池に石を投げると波紋が広がり**続ける** (後ろを残す) のは、水面が 2 次元だから。空気中の音や真空中の光がパルスとして鋭く伝わるのは、3 次元の Huygens 強原理。

---

## 10. 本章で出てきた記号 — まとめ

| 記号 | 意味 | 補足 |
|---|---|---|
| $\Box u$ | $u_{tt}-\Delta u$ | d'Alembertian / wave operator |
| $\square$ (本文末) | 証明終了 (Q.E.D.) | tombstone, Halmos symbol |
| $\Delta$ | 空間ラプラシアン $\sum_i \partial_{x_i}^2$ | 時間微分は含まない |
| $D$ または $\nabla$ | 勾配 (gradient) | Evans は $D$ を多用 |
| $u_{tt},u_{xx}$ など | 偏微分の略記 | $u_{tt}=\partial_t^2 u$ |
| $C^k(\Omega)$ | $\Omega$ 上 $k$ 階連続微分可能関数 | $C^\infty$ は無限階 |
| $\mathbb R_+$ | $\{x>0\}$ または $\{x\ge 0\}$ | 文脈依存 |
| $B(x,r)$ | 開球 $\{y:|y-x|<r\}$ | 中身 |
| $\partial B(x,r)$ | 球面 (球の境界) | 半径 $r$ |
| $\fint_E f$ | 平均積分 $\frac{1}{|E|}\int_E f$ | 「バー付き積分」 |
| $dS,\,dS(y)$ | 表面測度 | $n-1$ 次元面積要素 |
| $dy,\,dx$ | $n$ 次元 Lebesgue 体積要素 | |
| $\nu$ | 外向き単位法線 | 発散定理 |
| $\alpha(n)$ | 単位球の体積 | $\alpha(n)=\pi^{n/2}/\Gamma(n/2+1)$ |
| $n\alpha(n)$ | 単位球面の表面積 | $\partial B(0,1)$ の測度 |
| $\tilde u,\tilde U$ | チルダ — 反射拡張・$rU$ 変換等の補助関数 | 文脈ごとに役割が変わる |
| $\bar u,\bar g,\bar B$ | バー — **次元上げの拡張版** ($n=2\to n=3$) | **複素共役ではない** |
| $a(x),b(x)$ | (式 6, 7) 1 次元解の補助初期データ | 一時的記号 |
| $G,H,U$ | 球面平均 (式 12, 13) | 大文字で関数記号 |

---

## 11. 全体の物語の再確認 (発表用 1 枚絵)

```
        u_tt - Δu = 0,  u(·,0)=g, u_t(·,0)=h
                       │
        ┌──────────────┼──────────────┐
        │                              │
       n=1                          n≥2
        │                              │
   因数分解 (4)                  球面平均 U(x;r,t) (12)
   v=u_t-u_x                          │
        │                       Lemma 1: EPD 方程式 (14)
   輸送方程式 (5)                       │
        │                ┌─────────────┴─────────────┐
   d'Alembert (8)         n=3                       n=2
        │              Ũ = rU (17)             降下法 (23)
   反射法 (10)         1 次元波動方程式           (n=3 に埋め込む)
   半直線問題          反射法 (10) 適用 (20)         │
                        r→0+ で復元           Kirchhoff 公式 (22) を適用
                            ↓                        │
                      Kirchhoff (22)         半球→円板で投影
                       【n=3】                       │
                      強い Huygens                Poisson 公式 (n=2)
                                                  弱い Huygens
```

「**球面平均で角度方向を潰す → EPD → 適切変換で 1 次元波動方程式 → d'Alembert で解いて逆変換**」が全体の骨格。**奇数次元 ($n=3$) で解の依存域が球面に縮退して Huygens 強原理が成り立つ**点が物理的に最も印象的な結論です。

---

## 12. 発表で深掘りされそうな質問と回答メモ

1. **Q.** なぜ d'Alembert は「因数分解」で導けるのか?
   **A.** $\Box=\partial_t^2-\partial_x^2=(\partial_t+\partial_x)(\partial_t-\partial_x)$ という代数恒等式が $n=1$ でだけ成り立つから。$n\ge 2$ では $\partial_t^2-\Delta$ は実因子に分かれない (符号の関係で複素拡張が必要 = 「特性曲面の幾何」を考えるしかなくなる)。

2. **Q.** EPD 方程式の係数 $(n-1)/r$ はどこから?
   **A.** 極座標表示でのラプラシアンの動径成分。あるいは球面平均の動径微分公式 $\frac{d}{dr}\fint_{\partial B(x,r)} u\,dS = \frac{r}{n}\fint_{B(x,r)}\Delta u\,dy$ から $r$ 因子を 2 回追跡した結果として現れる。

3. **Q.** $\tilde U=rU$ がなぜ $n=3$ でだけ効くのか?
   **A.** $r U_{rr}+2U_r=(rU)_{rr}$ は係数 $2$ が「$rU$ の Leibniz 展開で $U_r$ が $2$ 個出る」ことに依存。EPD の係数 $n-1$ がちょうど $2$ になる $n=3$ で奇跡的に等しくなる。$n=2$ では $n-1=1$ なので合わない。

4. **Q.** Kirchhoff 公式の「球面のみ」と Huygens 強原理は何の話?
   **A.** $u(x,t)$ は半径 $t$ 球面の値で決まる = 距離 $t$ の点の初期データだけが効く。逆に言えば、コンパクトサポート初期データから出る波は、有限時間後にはサポート球殻の外を通り過ぎて消える ($u\to 0$)。これが「波動が後ろを残さない」性質 = 強原理。$n$ が偶数や $n=2$ では球の内部全体が効く (Poisson 公式) ので残響が残る。

5. **Q.** 「降下法 (descent)」はなぜ「上げる」ではなく「下げる」と呼ぶのか?
   **A.** $n$ 次元の問題を解くために $n+1$ 次元の (より対称的・解析しやすい) 問題に埋め込み、その解から元の次元へ「降りる」ことで $n$ 次元解を得るから。「上に昇って情報を取り、下に降ろす」イメージ。

6. **Q.** 反射法の「奇拡張」はなぜ「奇」?
   **A.** 奇関数は原点で値 $0$ を自動的に取るので、$x=0$ での Dirichlet 境界 $u=0$ がただちに保たれる。Neumann 境界 $u_x=0$ なら偶拡張を使う (Neumann に対しては偶関数の $x=0$ での導関数が $0$)。

7. **Q.** Theorem 1 の Remark (ii) — 滑らかさが上がらない、はなぜ重要?
   **A.** 熱方程式と対比される双曲型 PDE の本質的性質。特異性は伝播するし、有限伝播速度がある。物理的には「衝撃波」「不連続な波面」などをモデル化できる。

---

## 13. 補足参考文献 (続きを読みたい人へ)

- F. John, *Partial Differential Equations* (4th ed.) — d'Alembert, Kirchhoff, Poisson の導出と歴史を丁寧に
- W. Strauss, *Partial Differential Equations: An Introduction* (2nd ed.) — 学部レベルから段階的に
- G. Folland, *Introduction to Partial Differential Equations* — 関数解析的視点
- 谷島賢二『数理物理入門』, 小薗英雄・小川卓克『非線型偏微分方程式』 — 和書

写真は p.73 で切れているので、輪講準備には少なくとも **p.74–76 (Poisson 公式の完成、$n$ 一般、非斉次方程式 = Duhamel 原理)** まで併せて読むことを推奨します。

---

**作成日**: 2026-05-07
**対象**: 津川ゼミ輪講 (発表者: なかむら)
**底本**: Evans, *PDE* §2.4 pp.65–73 (`converted/IMG_3890.jpg`〜`IMG_3898.jpg`)
