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

= Organizzazioni per la Ricerca di Chiavi
Nell'ultima sezione del capitolo precedente abbiamo illustrato come l'organizzazione la gestione dei file in cui sono memorizzate le pagine vada ad influire enormemente sulle prestazioni di una base di dati. Oltre all'organizzazione seriale e sequenziale abbiamo a disposizione strutture molto più sofisticate che vedremo all'interno di questo capitolo.

Come già citato lo scopo di queste organizzazioni è quello di *localizzare un record* nella maniera più *veloce* possibile. Possiamo distinguere due metodi per organizzare i file:

- *organizzazioni primarie*: determinano come vengono memorizzati _fisicamente_ i dati all'interno del file. Nel momento in cui una chiave in questa organizzazione viene modificata, è anche necessario modificare la posizione fisica del record.
- *organizzazioni secondarie*: strutture dati che permettono di localizzare i record a partire da strutture dati secondarie, tipicamente si tratta di strutture basate su indici

Possiamo identificare diverse famiglie di organizzazione per i file. Per quanto riguarda le strutture primarie abbiamo quelle *hash based* o *tree based*. Per quanto riguarda le strutture secondarie abbiamo invece gli *indici*. Tutte queste famiglie possono essere inoltre classificate in *statiche* e *dinamiche*, a seconda che la struttura dati possa adattarsi a modifiche dettate da inserimenti e cancellazioni. Nel caso in cui la struttura sia _statica_ sarà necessario prevedere un meccanismo di _riorganizzazione_, mentre per quanto riguarda strutture _dinamiche_ queste saranno in grado di adattarsi automaticamente alle modifiche.

== Hashing Statico
Il principio alla base di queste tecniche è quello di utilizzare una *funzione di hash* per trasformare chiavi che potenzialmente non sono distribuite in maniera uniforme in valori che lo sono, permettendo così di distribuire i record in maniera uniforme all'interno dei vari file.

L'idea dietro a queste tecniche è abbastanza simile a quella dell'_accesso diretto_: supponiamo che dato un valore di chiave $K$ esista un unico posto  in cui il record $k$ possa essere memorizzato. Questo approccio è teoricamente molto efficiente, perché sapremmo per ogni chiave, dove ricercarla in maniera puntuale. Il problema è che questo richiede uno spazio di memorizzazione grande quando il dominio dei valori.
L'utilizzo di una funzione di *hash* ci permette di *restringere il dominio* dei possibili valori.

#figure(
  image("../images/ch08/hash_organization.png", width: 70%),
  caption: "Workflow di un'organizzazione hash-based",
)<fig:hash_workflow>

Come vediamo in @fig:hash_workflow ogni record viene sostanzialmente memorizzato in una pagina, a seconda di quello che è il valore di hash. Ovviamente se il dominio delle chiavi è molto grande, è da tenere in considerazione la possibilità di avere delle *collisioni*: per due valori diversi la funzione di hash potrebbe restituire lo stesso indirizzo. Quando lo spazio di una pagina viene esaurito, è necessario prevedere un meccanismo di *overflow* per gestire i record in eccesso.

Il motivo per cui questo approccio è detto *statico* è che una volta che un record viene memorizzato in una pagina, questo rimane lì fino a quando non viene cancellato. Come vediamo in @fig:hash_workflow, in questo approccio è necessario prevedere di gestire i seguenti aspetti:

- una *funzione* di *hash* $h(K)$ che data una chiave $K$ restituisce un indirizzo di pagina
- un modulo per la *gestione* dell'*overflow* che si occupa di gestire i record in eccesso quando una pagina è piena
- tenere in conto del *loading factor*: quanto spazio vuoto per ogni pagina andiamo a lasciare per gestire gli overflow
- tenere in considerazione la *capacità di una pagina*

#warning-box[È importante tenere in considerazione che questo approccio non è progettato per ricercare valori all'interno di un *intervallo*; non esiste infatti un meccanismo di ordinamento dei valori per cui non è possibile effettuare in maniera efficiente ricerche di questo tipo. ]
