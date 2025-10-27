# Shell (aka Corredor)
<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-2-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->

A wrapper to call shell commands from Swift code. A small part of the larger iOS deploy infrastructure at Plata.

## Usage

```swift
let result = Corredor.command(
    "git status", 
    arguments: ["--porcelain"], 
    options: .printOutput
).run()

// Working tree is clean! (or not)
...
```

If you're not into haha naming, just use `Shell.command...`, we understand.

## Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/adurymanov"><img src="https://avatars.githubusercontent.com/u/21358938?v=4?s=100" width="100px;" alt="Andrei"/><br /><sub><b>Andrei</b></sub></a><br /><a href="https://github.com/platacard/corredor/commits?author=adurymanov" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/mstroshin"><img src="https://avatars.githubusercontent.com/u/9129577?v=4?s=100" width="100px;" alt="Maksim Troshin"/><br /><sub><b>Maksim Troshin</b></sub></a><br /><a href="https://github.com/platacard/corredor/commits?author=mstroshin" title="Code">💻</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!