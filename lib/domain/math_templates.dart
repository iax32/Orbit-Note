class MathTemplate {
  const MathTemplate(this.name, this.tex, this.category);
  final String name, tex, category;
}

const mathLabTemplates = <MathTemplate>[
  MathTemplate(
    'Quadratic formula',
    r'x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}',
    'Algebra',
  ),
  MathTemplate('Pythagorean theorem', r'a^2+b^2=c^2', 'Geometry & games'),
  MathTemplate(
    'Euler formula',
    r'e^{i\theta}=\cos\theta+i\sin\theta',
    'Algebra',
  ),
  MathTemplate(
    'Fourier series',
    r'f(x)=\frac{a_0}{2}+\sum_{n=1}^{\infty}\left(a_n\cos nx+b_n\sin nx\right)',
    'Calculus',
  ),
  MathTemplate(
    'Laplace transform',
    r'F(s)=\int_0^{\infty} f(t)e^{-st}\,dt',
    'Calculus',
  ),
  MathTemplate(
    'Binomial probability',
    r'P(X=k)=\binom{n}{k}p^k(1-p)^{n-k}',
    'Probability',
  ),
  MathTemplate(
    '2D homogeneous transform',
    r'T=\begin{pmatrix}\cos\theta&-\sin\theta&t_x\\\sin\theta&\cos\theta&t_y\\0&0&1\end{pmatrix}',
    'Geometry & games',
  ),
  MathTemplate('Spring force', r'F=-kx', 'Physics'),
  MathTemplate('Kinetic energy', r'E_k=\frac{1}{2}mv^2', 'Physics'),
  MathTemplate('Angular frequency', r'\omega=2\pi f', 'Physics'),
  MathTemplate('Derivative', r'\frac{d}{dx} f(x)', 'Calculus'),
  MathTemplate(
    'Partial derivative',
    r'\frac{\partial f}{\partial x}',
    'Calculus',
  ),
  MathTemplate(
    'Gradient',
    r'\nabla f = \left(\frac{\partial f}{\partial x},\frac{\partial f}{\partial y},\frac{\partial f}{\partial z}\right)',
    'Calculus',
  ),
  MathTemplate(
    'Taylor series',
    r'f(x)=\sum_{n=0}^{\infty}\frac{f^{(n)}(a)}{n!}(x-a)^n',
    'Calculus',
  ),
  MathTemplate('Integration by parts', r'\int u\,dv=uv-\int v\,du', 'Calculus'),
  MathTemplate('Differential equation', r'\frac{dy}{dt}=\square', 'Calculus'),
  MathTemplate(
    'Dot product',
    r'\mathbf{a}\cdot\mathbf{b}=\sum_{i=1}^{n}a_i b_i',
    'Linear algebra',
  ),
  MathTemplate(
    'Cross product',
    r'\mathbf{a}\times\mathbf{b}=\begin{pmatrix}a_2b_3-a_3b_2\\a_3b_1-a_1b_3\\a_1b_2-a_2b_1\end{pmatrix}',
    'Linear algebra',
  ),
  MathTemplate(
    'Vector norm',
    r'\|\mathbf{v}\|=\sqrt{\sum_{i=1}^{n}v_i^2}',
    'Linear algebra',
  ),
  MathTemplate(
    'Eigenvalue equation',
    r'A\mathbf{v}=\lambda\mathbf{v}',
    'Linear algebra',
  ),
  MathTemplate(
    '2D rotation',
    r'R(\theta)=\begin{pmatrix}\cos\theta&-\sin\theta\\\sin\theta&\cos\theta\end{pmatrix}',
    'Geometry & games',
  ),
  MathTemplate(
    'Linear interpolation',
    r'\mathbf{p}(t)=(1-t)\mathbf{a}+t\mathbf{b}',
    'Geometry & games',
  ),
  MathTemplate(
    'Cubic Bezier curve',
    r'B(t)=(1-t)^3P_0+3(1-t)^2tP_1+3(1-t)t^2P_2+t^3P_3',
    'Geometry & games',
  ),
  MathTemplate(
    'Projectile motion',
    r'\mathbf{p}(t)=\mathbf{p}_0+\mathbf{v}_0t+\frac{1}{2}\mathbf{g}t^2',
    'Geometry & games',
  ),
  MathTemplate(
    'Distance',
    r'd=\sqrt{(x_2-x_1)^2+(y_2-y_1)^2}',
    'Geometry & games',
  ),
  MathTemplate(
    'Bayes theorem',
    r'P(A\mid B)=\frac{P(B\mid A)P(A)}{P(B)}',
    'Probability',
  ),
  MathTemplate('Expected value', r'E[X]=\sum_i x_i P(X=x_i)', 'Probability'),
  MathTemplate(
    'Variance',
    r'\operatorname{Var}(X)=E[X^2]-E[X]^2',
    'Probability',
  ),
  MathTemplate(
    'Normal distribution',
    r'f(x)=\frac{1}{\sigma\sqrt{2\pi}}e^{-\frac{(x-\mu)^2}{2\sigma^2}}',
    'Probability',
  ),
  MathTemplate(
    'Sample mean',
    r'\bar{x}=\frac{1}{n}\sum_{i=1}^{n}x_i',
    'Probability',
  ),
];
