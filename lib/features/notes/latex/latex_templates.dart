class LatexTemplate {
  const LatexTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.body,
  });

  final String id;
  final String name;
  final String description;
  final String body;

  String get content => body;
}

class LatexTemplates {
  static const blank = LatexTemplate(
    id: 'blank',
    name: 'Blank LaTeX Document',
    description: 'Clean academic article with standard mathematics packages.',
    body: r'''\documentclass[11pt, a4paper]{article}
\usepackage{amsmath, amssymb, amsthm}
\usepackage{graphicx}
\usepackage{booktabs}
\usepackage{hyperref}

\title{Untitled Document}
\author{Author Name}
\date{\today}

\begin{document}
\maketitle

\section{Introduction}
Start typing your document here. You can insert inline formulas like $E = mc^2$ or display equations:
\[
\int_{-\infty}^{\infty} e^{-x^2} \, dx = \sqrt{\pi}
\]

\end{document}
''',
  );

  static const assignment = LatexTemplate(
    id: 'assignment',
    name: 'University Assignment',
    description:
        'Problem sets and homework solutions with structured exercises.',
    body: r'''\documentclass[11pt, a4paper]{article}
\usepackage{amsmath, amssymb, amsthm}
\usepackage{geometry}
\geometry{margin=1in}

\title{MATH 301: Real Analysis --- Homework 1}
\author{Student Name (ID: 12345678)}
\date{\today}

\begin{document}
\maketitle

\section*{Problem 1}
Prove that for any real numbers $a, b \in \mathbb{R}$,
\[
|a + b| \le |a| + |b|
\]

\begin{proof}
Let $a, b \in \mathbb{R}$. Note that $-|a| \le a \le |a|$ and $-|b| \le b \le |b|$.
Adding these inequalities yields:
\[
-(|a| + |b|) \le a + b \le |a| + |b|
\]
By the definition of absolute value, this directly implies $|a + b| \le |a| + |b|$.
\end{proof}

\section*{Problem 2}
Evaluate the definite integral:
\[
I = \int_{0}^{1} \frac{x}{\sqrt{1 - x^2}} \, dx
\]

\subsection*{Solution}
Using substitution $u = 1 - x^2$, we have $du = -2x \, dx$:
\begin{aligned}
I &= -\frac{1}{2} \int_{1}^{0} u^{-1/2} \, du \\
  &= \left[ u^{1/2} \right]_{0}^{1} = 1
\end{aligned}

\end{document}
''',
  );

  static const exerciseSheet = LatexTemplate(
    id: 'exercise_sheet',
    name: 'Math Exercise Sheet',
    description:
        'Definitions, theorems, lemmas, and proofs for study and coursework.',
    body: r'''\documentclass[11pt, a4paper]{article}
\usepackage{amsmath, amssymb, amsthm}

\newtheorem{theorem}{Theorem}[section]
\newtheorem{lemma}[theorem]{Lemma}
\newtheorem{definition}[theorem]{Definition}
\newtheorem{corollary}[theorem]{Corollary}

\title{Linear Algebra: Diagonalization Exercises}
\author{Course Study Group}
\date{\today}

\begin{document}
\maketitle

\section{Eigenvalues and Eigenspaces}

\begin{definition}
Let $A \in M_{n \times n}(\mathbb{R})$. A non-zero vector $v \in \mathbb{R}^n$ is an eigenvector corresponding to eigenvalue $\lambda$ if:
\[
A v = \lambda v
\]
\end{definition}

\begin{theorem}
Eigenvectors corresponding to distinct eigenvalues are linearly independent.
\end{theorem}

\begin{proof}
Suppose $v_1, \dots, v_k$ are eigenvectors corresponding to distinct eigenvalues $\lambda_1, \dots, \lambda_k$. We proceed by induction on $k$.
For $k=1$, $v_1 \neq 0$, so $\{v_1\}$ is independent.
Assume the theorem holds for $k-1$ vectors. If:
\[
c_1 v_1 + \dots + c_k v_k = 0
\]
Applying $A - \lambda_k I$ eliminates $v_k$, implying $c_1 = \dots = c_{k-1} = 0$, and therefore $c_k = 0$.
\end{proof}

\end{document}
''',
  );

  static const researchPaper = LatexTemplate(
    id: 'research_paper',
    name: 'Research Paper / Report',
    description:
        'Academic article with abstract, sections, figures, tables, and bibliography.',
    body: r'''\documentclass[11pt, a4paper]{article}
\usepackage{amsmath, amssymb}
\usepackage{graphicx}
\usepackage{booktabs}
\usepackage{hyperref}

\title{A Computational Study of Neural Network Optimization Landscapes}
\author{Department of Computer Science \\ University of Science}
\date{\today}

\begin{document}
\maketitle

\begin{abstract}
We analyze stochastic gradient descent dynamics in non-convex loss surfaces. Empirical results demonstrate convergence rates consistent with theoretical bounds.
\end{abstract}

\section{Introduction}
Non-convex optimization is fundamental to modern deep learning. We investigate the objective function:
\[
\min_{\theta \in \mathbb{R}^d} \mathcal{L}(\theta) = \frac{1}{N} \sum_{i=1}^{N} \ell(f(x_i; \theta), y_i)
\]

\section{Methods}
We evaluate momentum and adaptive step sizes:
\begin{align}
m_t &= \beta m_{t-1} + (1 - \beta) g_t \\
\theta_{t+1} &= \theta_t - \alpha m_t
\end{align}

\section{Experimental Results}
Table \ref{tab:results} summarizes final validation accuracy across test sets.

\begin{table}[h]
\centering
\begin{tabular}{lcc}
\toprule
Optimizer & Epochs & Top-1 Accuracy (\%) \\
\midrule
SGD & 100 & 92.4 \\
AdamW & 100 & 94.1 \\
OrbitOpt & 100 & 95.8 \\
\bottomrule
\end{tabular}
\caption{Comparison of optimizer performance.}
\label{tab:results}
\end{table}

\section{Conclusion}
Our findings show consistent acceleration when adaptive moments are combined with curvature regularization.

\end{document}
''',
  );

  static const formulaSheet = LatexTemplate(
    id: 'formula_sheet',
    name: 'Exam Formula Sheet',
    description:
        'Compact multi-section reference sheet for exam review and quick lookup.',
    body: r'''\documentclass[10pt, a4paper]{article}
\usepackage{amsmath, amssymb}
\usepackage{geometry}
\geometry{margin=0.5in}

\title{Comprehensive Mathematics Formula Sheet}
\date{\today}

\begin{document}
\maketitle

\section*{Calculus Fundamentals}
\begin{itemize}
\item Product Rule: $(uv)' = u'v + uv'$
\item Quotient Rule: $\left(\frac{u}{v}\right)' = \frac{u'v - uv'}{v^2}$
\item Chain Rule: $\frac{d}{dx} f(g(x)) = f'(g(x)) g'(x)$
\item Integration by Parts: $\int u \, dv = uv - \int v \, du$
\end{itemize}

\section*{Series \& Expansions}
\begin{align*}
e^x &= \sum_{n=0}^{\infty} \frac{x^n}{n!} = 1 + x + \frac{x^2}{2!} + \dots \\
\sin x &= \sum_{n=0}^{\infty} (-1)^n \frac{x^{2n+1}}{(2n+1)!} \\
\cos x &= \sum_{n=0}^{\infty} (-1)^n \frac{x^{2n}}{(2n)!}
\end{align*}

\section*{Linear Algebra}
\begin{itemize}
\item Matrix Inverse ($2 \times 2$):
\[
\begin{pmatrix} a & b \\ c & d \end{pmatrix}^{-1} = \frac{1}{ad - bc} \begin{pmatrix} d & -b \\ -c & a \end{pmatrix}
\]
\item Characteristic Equation: $\det(A - \lambda I) = 0$
\end{itemize}

\end{document}
''',
  );

  static const theoremProof = LatexTemplate(
    id: 'theorem_proof',
    name: 'Theorems & Mathematical Proofs',
    description:
        'Formal mathematics with theorem, lemma, proposition, definition, and proof environments.',
    body: r'''\documentclass[11pt, a4paper]{article}
\usepackage{amsmath, amssymb, amsthm}
\usepackage{geometry}
\geometry{margin=1in}

\newtheorem{theorem}{Theorem}[section]
\newtheorem{lemma}[theorem]{Lemma}
\newtheorem{proposition}[theorem]{Proposition}
\newtheorem{corollary}[theorem]{Corollary}
\theoremstyle{definition}
\newtheorem{definition}{Definition}[section]
\newtheorem{example}{Example}[section]
\theoremstyle{remark}
\newtheorem*{remark}{Remark}

\title{Theorems and Mathematical Rigor}
\author{Author Name}
\date{\today}

\begin{document}
\maketitle

\section{Foundational Definitions}

\begin{definition}[Metric Space]
A metric space is an ordered pair $(M, d)$ where $M$ is a set and $d: M \times M \to \mathbb{R}$ satisfies positivity, symmetry, and the triangle inequality:
\[
d(x, z) \le d(x, y) + d(y, z) \quad \forall x, y, z \in M
\]
\end{definition}

\section{Main Results}

\begin{theorem}[Banach Fixed-Point Theorem]
Let $(X, d)$ be a non-empty complete metric space with contraction mapping $T: X \to X$. Then $T$ admits a unique fixed point $x^* \in X$ such that $T(x^*) = x^*$.
\end{theorem}

\begin{proof}
Let $x_0 \in X$ and define $x_n = T(x_{n-1})$ for $n \ge 1$. By the contraction property with constant $k < 1$:
\[
d(x_{n+1}, x_n) \le k^n d(x_1, x_0)
\]
Since $\sum k^n < \infty$, $(x_n)$ is a Cauchy sequence. As $X$ is complete, $\lim_{n \to \infty} x_n = x^*$. By continuity of $T$:
\[
T(x^*) = T\left(\lim_{n \to \infty} x_n\right) = \lim_{n \to \infty} x_{n+1} = x^*
\]
Uniqueness follows directly from the contraction inequality.
\end{proof}

\end{document}
''',
  );

  static const List<LatexTemplate> all = [
    blank,
    assignment,
    exerciseSheet,
    researchPaper,
    formulaSheet,
    theoremProof,
  ];
}
