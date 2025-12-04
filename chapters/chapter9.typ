#import "@preview/theorion:0.4.0": *
#import cosmos.fancy: *
#show: show-theorion
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#show: codly-init.with()
#import "../lib.typ": *

// apply numbering up to h3
#show heading: it => {
  if (it.level > 3) {
    block(it.body)
  } else {
    block(counter(heading).display() + " " + it.body)
  }
}

// Numerazione delle figure per capitolo
#set figure(numbering: num => {
  let chapter = counter(heading.where(level: 1)).get().first()
  numbering("1.1", chapter, num)
})

// Numerazione delle equazioni per capitolo
#set math.equation(numbering: num => {
  let chapter = counter(heading.where(level: 1)).get().first()
  numbering("(1.1)", chapter, num)
})

// Resetta i contatori ad ogni nuovo capitolo
#show heading.where(level: 1): it => {
  counter(figure.where(kind: image)).update(0)
  counter(figure.where(kind: table)).update(0)
  counter(math.equation).update(0)
  it
}

= Organizzazioni e Indici Multidimensionali
Nello scorso capitolo abbiamo visto come i file possono essere organizzati in maniera tale da rendere più efficienti le operazioni di accesso ai dati sulla base di alcuni attributi. Come abbiamo visto possiamo fornire delle organizzazioni primarie, che possono essere statiche o dinamiche, oppure degli *indici* che permettono di accedere ai dati in maniera efficiente anche quando l'organizzazione primaria non è adatta a soddisfare le richieste delle query.

Tutto ciò che abbiamo visto nel capitolo precedente si basa su strutture dati *mono-dimensionali*, ovvero strutture che permettono di organizzare i dati sulla base di un singolo attributo. Tuttavia nella maggior parte dei contesti avremo in realtà a che fare con dati che sono per loro natura *multi-dimensionali*.

Un esempio molto comune di dati multi-dimensionali sono i dati _spaziali_, ovvero dati che rappresentano oggetti nello spazio, come ad esempio punti, linee, poligoni, ecc. Questi dati sono caratterizzati da più attributi che rappresentano le coordinate spaziali (ad esempio latitudine e longitudine) e spesso è necessario effettuare query che coinvolgono più di un attributo (ad esempio trovare tutti i punti all'interno di una certa area geografica).
