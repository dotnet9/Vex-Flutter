# Markdown 公式与渲染设置

The Markdown preferences page contains seven persisted switches: mathematics,
chemistry, Mermaid, subscript/superscript, highlights, automatic links and soft
line breaks. The same configuration drives instant editing, reading,
presentations and HTML/PDF/Word exports. These switches never rewrite source or
create editing-history entries. Mathematics and chemistry are independent.

## Native rendering

Vex uses `val_latex_flutter` 0.1.3, including its native mhchem implementation and
bundled math fonts. No JavaScript, browser engine, CDN or remote TeX service is
required. Verified examples include inline variables, quadratic equations,
fractions, roots, integrals, matrices, chemical reactions, equilibrium arrows
and charged ions. This is a supported TeX/mhchem subset, not a complete TeX
distribution or a promise that arbitrary LaTeX packages work.

Supported formula delimiters are `$...$`, `$$...$$`, `\(...\)` and `\[...\]`.
Prices, escaped dollar signs and code spans/fences remain ordinary Markdown.
Standalone display formulas retain blank lines and original line endings.
Selecting a display formula unfolds its source above the preview. Edits share
the document undo history, wait for IME composition, and are retained on Escape
or clicking outside. Invalid expressions retain readable source.

Inline extensions use `==highlight==`, `H~2~O` and `x^2^`. Strikethrough uses
`~~text~~`, so disabling subscripts does not silently turn them into deletion
marks. Disabling automatic links does not disable explicit Markdown links.
Soft line break preferences do not affect explicit hard breaks or code.

## Exports and limits

Formulas are rasterized with the same native typesetter and embedded as offline
PNG images in HTML, PDF and Word. HTML dimensions are font-relative. PDF/Word
keep normal text as text; formulas are images, not editable Office equations.
Invalid formulas fall back to escaped source. Mermaid keeps its SVG HTML/PDF
export and PNG Word export. Turning Mermaid off exports its source as code.

Formula source is bounded to 8 KiB. Parser expansion, nesting, node, token,
dimension and time limits guard untrusted formulas. TeX URL/image/HTML trust is
disabled. Image exports have bounded dimensions and pixel area.

Verification includes all ten approved formula examples, source-preserving
block parsing, independent preferences, headings/table cells, offline exports,
shared undo/CRLF/IME, phone light/dark layouts, and native Windows captures at
1280x900 and 390x844. Review captures live in ignored
`artifacts/review/markdown-2026-10-18/`.
