import Foundation

enum Assets {
    /// Claude logo (claude.ai favicon path), accent color D97757.
    static let claudeLogoSVG = """
    <svg viewBox="0 0 248 248" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M52.43 162.87 98.78 136.88l.77-2.28-.77-1.27h-2.3l-7.77-.47-26.49-.71-22.92-.95-22.29-1.18-5.6-1.18-5.22-6.97.51-3.43 4.71-3.19 6.75.59 14.9 1.06 22.41 1.54 16.18.95 23.97 2.48h3.82l.51-1.54-.95-.95-.94-.95L74.59 102.73 49.5 86.19 36.38 76.62l-7-4.84-3.57-4.49-1.53-9.93 6.37-7.09 8.66.59 2.16.59 8.79 6.73 18.72 14.53 24.45 17.96 3.57 2.95 1.43-.97.22-.69-1.65-2.71L83.76 65.28 69.62 40.82l-6.37-10.16-1.66-6.03c-.64-2.53-1.02-4.62-1.02-7.2L67.84 7.5l4.07-1.3 9.81 1.3 4.13 3.54 6.11 13.94 9.81 21.86 15.28 29.77 4.46 8.86 2.42 8.15.89 2.48h1.53v-1.42l1.27-16.78 2.29-20.56 2.29-26.47.77-7.44 3.69-8.98 7.39-4.84 5.73 2.72 4.71 6.74-.64 4.37-2.8 18.2-5.48 28.47-3.56 19.14h2.04l2.42-2.48 9.68-12.76 16.17-20.32 7.13-8.03 8.41-8.86 5.35-4.25h10.19l7.39 11.11-3.31 11.46-10.44 13.23-8.66 11.22-12.42 16.64-7.7 13.37.69 1.11 1.86-.16 28.02-6.03 15.15-2.72 18.08-3.07 8.15 3.78.89 3.9-3.18 7.92-19.36 4.72-22.67 4.61-33.76 7.95-.37.3.44.65 15.22 1.38 6.5.35h15.92l29.67 2.25 7.77 5.08 4.59 6.26-.77 4.84-11.97 6.03-16.05-3.78-37.57-8.98-12.86-3.19h-1.78v1.06l10.7 10.52 19.74 17.72 24.58 22.92 1.27 5.67-3.18 4.49-3.31-.47-21.65-16.3-8.41-7.33-18.85-15.95h-1.27v1.65l4.33 6.38 23.05 34.62 1.15 10.63-1.66 3.43-5.99 2.13-6.49-1.18-13.63-19.02-13.88-21.27-11.21-19.14-1.35.86-6.67 71.22-3.06 3.66-7.13 2.72-5.99-4.49-3.18-7.33 3.18-14.53 3.82-18.91 3.06-15.01 2.8-18.67 1.71-6.24-.15-.42-1.37.23-14.07 19.3-21.4 28.95-16.94 18.08-4.07 1.65-7.01-3.66.64-6.5 3.95-5.79 23.43-29.78 14.14-18.55 9.11-10.65.09-1.54-.5-.04L46.7 188.51l-11.08 1.42-4.84-4.49.64-7.33 2.29-2.36 18.72-12.88Z" fill="#D97757"/></svg>
    """

    /// A simple neutral "user" mark.
    static let userIconSVG = """
    <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><circle cx="12" cy="8" r="4" fill="#0969da"/><path d="M4 21c0-4.418 3.582-7 8-7s8 2.582 8 7" fill="#0969da"/></svg>
    """

    static let css = """
    :root {
      --fg: #1f2328;
      --muted: #59636e;
      --faint: #818b98;
      --border: #d1d9e0;
      --bg: #ffffff;
      --code-bg: #f6f8fa;
      --code-fg: #1f2328;
      --accent: #d97757;
      --link: #0969da;
      --user: #0969da;
      --user-bg: #f6f8fc;
      --user-border: #d6e2f4;
      --error: #b42318;
      --error-bg: #fff5f4;
    }
    * { box-sizing: border-box; }
    html { -webkit-text-size-adjust: 100%; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--fg);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      font-size: 16px;
      line-height: 1.5;
    }
    .wrap { max-width: 880px; margin: 0 auto; padding: 48px 24px 160px; }

    header.meta { border-bottom: 1px solid var(--border); padding: 0 17px 22px; margin-bottom: 16px; }
    header.meta h1 { font-size: 20px; line-height: 1.4; margin: 0 0 14px; font-weight: 650; }
    header.meta dl { display: grid; grid-template-columns: max-content 1fr; gap: 4px 14px; margin: 0;
      font-size: 12.5px; color: var(--muted); }
    header.meta dt { color: var(--faint); }
    header.meta dd { margin: 0; word-break: break-all; }

    .turn { margin: 24px 0 0; padding: 0 17px; }
    .turn:first-child { margin-top: 0; }
    .turn.continued { margin-top: 13px; }
    .turn.continued.tool-only { margin-top: 3px; }
    .role { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }
    .role .icon { width: 20px; height: 20px; display: inline-flex; }
    .role .icon svg { width: 100%; height: 100%; }
    .role .name { font-weight: 650; font-size: 13.5px; }
    .role.claude .name { color: var(--accent); }
    .role.you .name { color: var(--user); font-weight: 700; }
    /* Every turn is padded 17px, so the You box (border 1px + padding 16px = 17px)
       lines its content up with Claude's — no negative-margin hack needed. */
    .turn.you { background: var(--user-bg); border: 1px solid var(--user-border);
      border-radius: 8px; padding: 12px 16px; }
    .role .time { margin-left: auto; font-size: 11.5px; color: var(--faint); font-variant-numeric: tabular-nums; }

    .body > *:first-child { margin-top: 0; }
    .body > *:last-child { margin-bottom: 0; }
    .md { line-height: 1.5; }
    .md p { margin: 0 0 16px; }
    .md h1, .md h2, .md h3, .md h4, .md h5, .md h6 { margin: 24px 0 16px; line-height: 1.25; font-weight: 600; }
    .md h1 { font-size: 1.7em; padding-bottom: .3em; border-bottom: 1px solid var(--border); }
    .md h2 { font-size: 1.35em; padding-bottom: .3em; border-bottom: 1px solid var(--border); }
    .md h3 { font-size: 1.15em; }
    .md h4 { font-size: 1em; }
    .md h5 { font-size: .9em; } .md h6 { font-size: .85em; color: var(--muted); }
    .md ul, .md ol { margin: 0 0 16px; padding-left: 2em; }
    .md li { margin: 2px 0; }
    .md li > ul, .md li > ol { margin: 2px 0; }
    .md li.task { list-style: none; margin-left: -1.4em; }
    .md a { color: var(--link); text-decoration: none; }
    .md a:hover { text-decoration: underline; }
    .md blockquote { margin: 0 0 16px; padding: 0 1em; border-left: .25em solid var(--border); color: var(--muted); }
    .md hr { height: .25em; padding: 0; margin: 24px 0; background: var(--border); border: 0; }
    .md img { max-width: 100%; max-height: 50vh; height: auto; border-radius: 6px; }
    .md table { border-collapse: collapse; margin: 0 0 16px; font-size: 14px;
      display: block; width: max-content; max-width: 100%; overflow: auto; }
    .md table th, .md table td { border: 1px solid var(--border); padding: 6px 13px; }
    .md table th { font-weight: 600; }
    .md table tr { border-top: 1px solid var(--border); }
    .md tbody tr:nth-child(2n) { background: var(--code-bg); }

    code { font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace; }
    :not(pre) > code { background: rgba(129,139,152,0.15); padding: .2em .4em; border-radius: 6px; font-size: 85%; }
    pre { background: var(--code-bg); color: var(--code-fg); padding: 16px; border-radius: 6px;
      overflow: auto; margin: 0 0 16px; font-size: 85%; line-height: 1.45; }
    pre code { font-size: 100%; }

    .inline-image { max-width: 100%; max-height: 50vh; height: auto; border-radius: 6px; margin: 4px 0; }

    /* Tool & skill calls — quiet, foldable footnotes rather than boxed cards. */
    details.tool { margin: 2px 0; }
    details.tool + details.tool { margin-top: 0; }
    details.tool > summary { cursor: pointer; padding: 1px 0; list-style: none;
      display: flex; align-items: baseline; gap: 6px; font-size: 12px; color: var(--faint); }
    details.tool > summary::-webkit-details-marker { display: none; }
    details.tool > summary::before { content: "▸"; color: var(--faint); font-size: 9px; }
    details.tool[open] > summary::before { content: "▾"; }
    details.tool > summary:hover { color: var(--muted); }
    details.tool > summary:hover .tool-name { color: var(--fg); }
    .tool-name { font-weight: 600; font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 11.5px; color: var(--muted); }
    .tool-gist { color: var(--faint); font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 11.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .tool-body { padding: 8px 0 2px; margin: 5px 0 5px 4px; padding-left: 13px;
      border-left: 2px solid var(--border); }
    .tool-body pre { margin: 0 0 8px; background: var(--code-bg); }
    .tool-body > *:last-child { margin-bottom: 0; }
    .tool-kv { font-size: 12px; color: var(--muted); margin: 0 0 8px; font-family: ui-monospace, Menlo, monospace; }
    .tool-result { margin-top: 8px; }
    .tool-result-label { font-size: 10px; text-transform: uppercase; letter-spacing: 0.05em; color: var(--faint); margin-bottom: 4px; }
    .tool-result.error pre { background: var(--error-bg); color: var(--error); }
    .truncated { color: var(--faint); font-size: 12px; font-style: italic; }
    details.sub > summary .tool-name { color: #8077c0; }

    .note { margin: 6px 17px; font-size: 12px; color: var(--faint);
      display: flex; gap: 7px; align-items: baseline; }
    .note::before { content: "⤷"; font-size: 11px; }

    .turn.meta-turn { margin: 10px 0 0; }
    details.meta { border: 1px dashed var(--border); border-radius: 8px; background: #fafbfc; overflow: hidden; }
    details.meta > summary { cursor: pointer; padding: 6px 12px; list-style: none;
      display: flex; align-items: baseline; gap: 8px; font-size: 12px; color: var(--faint); }
    details.meta > summary::-webkit-details-marker { display: none; }
    details.meta > summary::before { content: "▸"; font-size: 10px; }
    details.meta[open] > summary::before { content: "▾"; }
    .meta-tag { text-transform: uppercase; letter-spacing: 0.05em; font-size: 10px; font-weight: 650; }
    .meta-gist { color: var(--muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
    .meta-body { padding: 10px 14px; border-top: 1px solid var(--border); font-size: 13px; color: var(--muted); }
    .meta-body pre, .meta-body code { font-size: 11.5px; }
    .meta-body > *:first-child { margin-top: 0; }
    .meta-body > *:last-child { margin-bottom: 0; }
    details.meta.compact { border-style: solid; border-color: var(--user-border); background: var(--user-bg); }
    details.meta.compact > summary .meta-tag { color: var(--accent); }
    """
}
