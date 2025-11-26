#import "lib.typ": *
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#show: codly-init.with()

#import "@preview/theorion:0.4.0": *
#import cosmos.fancy: *

#set text(
  lang: "it",
)

#show: ilm.with(
  title: [Advanced Data Management],
  author: "Federico Segala",
  imagePath: "images/unilogo.png",
  abstract: [
    Anno Accademico: 2025-2026#linebreak()
    Appunti del corso di Advanced Data Management #linebreak()
    prof. Claudio Silvestri
  ],
)


// 1. Change the counters and numbering:
#set-inherited-levels(1)
#set-zero-fill(true)
#set-leading-zero(true)
#set-theorion-numbering("1.1")


#show heading.where(level: 1): set text(size: 22pt)
#show heading.where(level: 2): set text(size: 17pt)
#show heading.where(level: 3): set text(size: 14pt)
#show heading.where(level: 4): set text(size: 14pt)
#show heading.where(level: 5): set text(size: 12pt)


#outline(
  title: "Sommario",
  depth: 3,
)

#pagebreak()


#include "chapters/chapter1.typ"
#pagebreak()
#include "chapters/chapter2.typ"
#pagebreak()
#include "chapters/chapter3.typ"
#pagebreak()
#include "chapters/chapter4.typ"
#pagebreak()
#include "chapters/chapter5.typ"
#pagebreak()
#include "chapters/chapter6.typ"
#pagebreak()
#include "chapters/chapter7.typ"
#pagebreak()



#pagebreak()
#outline(
  title: "Indice delle figure",
  target: figure.where(kind: image),
)


// keep this stuff down here to avoid numbering toc and stuff like that


// only apply numbering to figures with captions
#show figure: it => {
  if it.caption != none {
    numbering("Figure 1")
  }
  it
}

