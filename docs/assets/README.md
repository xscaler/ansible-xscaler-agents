# Diagram logo assets

`architecture.svg` can show official product logos instead of the simplified built-in icons.
Logos are **not** committed here — download the official asset and save it with the exact
filename below, then uncomment the matching `<image>` line in `architecture.svg`.

| Filename to save     | Official source                                              | Terms |
|----------------------|-------------------------------------------------------------|-------|
| `otel.svg`           | https://github.com/cncf/artwork (opentelemetry)             | CNCF, CC-BY 4.0 — free with attribution |
| `linux.svg`          | https://commons.wikimedia.org/wiki/File:Tux.svg (Tux)       | Free to use; credit "lewing@isc.tamu.edu and The GIMP" |
| `windows.svg`        | Microsoft Brand/Trademark Guidelines (license required)     | ⚠️ Restricted — do **not** embed without permission from Microsoft |

## How to enable

1. Save the file(s) into this folder with the names above.
2. In `architecture.svg`, find the `<!-- LOGO SLOT: ... -->` comments and replace the drawn
   icon group with, e.g.:
   ```xml
   <image href="assets/linux.svg" x="58" y="118" width="34" height="48"/>
   ```
3. Keep an attribution line in the page (the diagram footer already carries a generic note).

## Windows

Microsoft's trademark guidelines do not permit embedding the Windows logo in third-party
material without a license. Leave the generic server icon for the Windows host (or use the
word "Windows"), unless you have written permission. This is a trademark restriction, not a
copyright one — "it's documentation" does not exempt it.
