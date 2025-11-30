#import "@preview/theorion:0.4.0": *
#import cosmos.fancy: *
#import "@preview/cetz:0.4.2": canvas, draw, tree
#import "../lib.typ": *

// #import cosmos.rainbow: *
// #import cosmos.clouds: *
#show: show-theorion


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

= Introduzione
Le basi di dati sono elementi fondamentali in molti aspetti della tecnologia quotidiana. Ogni giorno infatti, è prodotta, memorizzata e elaborata una *immensa quantità di dati*.

Un *database management system* che funzioni in maniera corretta è dunque cruciale per rendere queste attività il più semplici ed efficaci possibili. Questo capitolo si occupa di introdurre _principi_ e _proprietà_ che un database dovrebbe soddisfare.
== Proprietà di una Base di Dati
Dal momento che lo storage di dati è cruciale, un database dovrebbe garantire le proprietà che andiamo di seguito a definire.

- *Gestione dei dati*:
  Una base di dati non si occupa solo del salvataggio, ma deve supportare operazioni che permettano recupero, ricerca, e aggiornamento dei dati. Per fare ciò spesso è necessario avere delle interfacce tramite le quali sia possibile comunicare con la base di dati. Un altro aspetto importante è quello del supporto alle transazioni, ossia insiemi di operazioni atomici, non interrompibili.


- *Scalabilità*:  La quantità di dati processati è di solito enorme. Elaborare questa mole di dati è fattibile solamente *distribuendoli* in una rete e garantendo un alto livello di parallelismo. La necessità in questo caso è di _adattarsi al workload corrente_ del sistema e allocare risorse di conseguenza.

- *Eterogeneità*:  Nel momento in cui andiamo a memorizzare dati questi non sono tipicamente nella forma corretta per essere memorizzati in forma relazionale; I dati possono essere memorizzati in maniera *strutturata* ma non solo. Possono infatti essere *semi-strutturati*, altre forme tipiche sono strutture ad *albero* (XML) o a *grafo*, nel peggiore dei casi, si può avere un dato che è completamente non strutturato.

- *Efficienza*: La maggioranza delle applicazioni hanno bisogno di sistemi molto veloci in modo da riflettere nel minor tempo possibile i cambiamenti (real time applications).

- *Persistenza*: Lo scopo principale di una base di dati è quello di fornire storage a lungo termine dei dati. Ci sono delle eccezioni a questo, casi in cui solo parti dei dati necessità permanenza a lungo termine, mentre altri sono più _volatili_; questo comportamento è chiamato *persistenza selettiva*.

- *Affidabilità*: Un buon sistema è tipicamente in grado di prevenire la perdita di dati o l'avvenimento di distorsioni degli stessi. In pratica ciò cu sui ci si concentra è l'*integrità* dei dati. Ciò avviene tipicamente tramite _ridondanza fisica_ e _replicazione_.

- *Consistenza*: È importante che la base di dati garantisca che non siano presenti dati contradditori o errati nel sistema. Ciò si ottiene tipicamente tramite chiavi primarie, integrità referenziale e aggiornamento automatico delle repliche dei dati.

- *Non Ridondanza*: La ridondanza fisica è cruciale per garantire affidabilità, la duplicazione di valori (_ridondanza logica_) è invece da evitare per quanto possibile. Ciò aumenta inutilmente il consumo di spazio e la possibilità di _anomalie_.

- *Supporto multi-utente*: Nei sistemi moderni è spesso richiesto il supporto all'accesso concorrente alle risorse da parte di più utenti o applicazioni.

Tutte queste caratteristiche ci consentono di formalizzare nel modo più completo possibile cosa sia una database management system (DBMS) come riporta #ref(<def:dbms>)

#definition(title: "Base di Dati")[
  Una base di dati è un sistema che consente di gestire grandi quantità di dati eterogenei, in maniera efficiente, persistente, affidabile, consistente e non ridondante. È inoltre in grado di supportare accesso concorrente da parte di più utenti.
]<def:dbms>

Tipicamente è complicato che una base di dati supporti tutte le caratteristiche elencate di sopra; si rivela dunque fondamentale un'*analisi* dettagliata dei *requisiti* di ogni caso d'uso per rendere il più ponderata possibile la scelta del sistema da utilizzare.

== Componenti di un Database
Il componente software che si fa carico di tutte le operazioni sulla base di dati è il *database management system* (DBMS). #ref(<fig:dbms_interactions>) illustra come molti altri componenti nel sistema operativo vadano a interagire tra di loro e con questo importante elemento.
#figure(
  image("../images/ch01/dbms_interactions.png"),
  caption: [Interazioni del DBMS],
)<fig:dbms_interactions>

A seconda delle necessità che vengono specificate dai requisiti, è possibile andare a concentrarsi su una specifica implementazione. Andando oltre alle peculiarità associate ad ogni diverso prodotto, è possibile identificare i seguenti elementi comuni a tutti i DMBS:

- *Gestione della memoria persistente*: si occupa di salvare i dati nel file system
- *Gestione del buffer*: si occupa, collaborando con il gestore della memoria, di effettuare _swap in/out_ di varie pagine della memoria persistente in base a ciò che è richiesto dall'operazione che si sta eseguendo

Il gestore del buffer potrebbe sembrare molto simile al _sistema_ di paginazione utilizzato sui comuni sistemi operativi. La differenza consiste nel fatto che il gestore del buffer è a conoscenza del tipo di operazione che è in esecuzione all'interno del database.

- *Strutture dati* per la memoria secondaria: si usano tipicamente per ottenere maggiore efficienza rispetto allo swap in/out delle pagine
- *Metodi di accesso*: consistono in un modo per accedere ai dati in memoria secondaria seguendo specifici _pattern_ in base all'operazione che è necessario eseguire
- *Gestione delle transazioni*: si occupa di eseguire sequenze di operazioni in maniera atomica, mantenendo la consistenza del sistema
- *Gestione della concorrenza*: si occupa di garantire che molti processi siano abilitati ad accedere al database nello stesso momento. In linea di massima garantisce che le richieste parallele seguano uno schedule sequenziale

Per fare un esempio di ciò, immaginiamo che sia necessario gestire in maniera concorrente le seguenti transazioni: $T_1, T_2, T_3$; ci sono $(3!)$ 6 possibili scheduling sequenziali che possiamo scegliere di seguire per soddisfarle:

#align(center)[
  #list_twocols[
    - $T_1, T_2, T_3$
    - $T_1, T_3, T_2$
    - $T_2, T_1, T_3$
    - $T_2, T_3, T_1$
    - $T_3, T_2, T_1$
    - $T_3, T_1, T_2$
  ]]

compito del gestore della concorrenza è quello di fare in modo che il risultato del sistema dopo aver eseguito in concorrenza le tre transazioni sia equivalente al risultato di uno casuale degli scheduling sequenziali di sopra riportati.

- *Operatori fisici*: ne esistono alcuni che sono comuni a più famiglie di basi di dati, altri che sono specifici di singole famiglie. Si tratta di operazioni rese disponibili tramite API che quando eseguite su un insieme di dati garantiscono un certo risultato

La maggior parte di questi operatori fisici, nel caso di database relazionali, sono in diretta corrispondenza con operatori dell'_algebra relazionale_; ad esempio, operazioni di _filtering_ corrispondono alla clausola `WHERE`, mentre alcune operazioni di _proiezione_ corrispondono alla clausola `SELECT`.

- *Ottimizzatore delle query*: ipotizziamo di voler effettuare un'operazione di `JOIN`. Sappiamo che esistono molte variante di questa operazione, il compito di questa componente è quello di scegliere il tipo di implementazione da utilizzare per rendere il più efficiente possibile la valutazione della query in esame

- *Frammentazione dei dati*: esistono casi in cui i dati non sono salvati in un'unica posizione (potrebbero essere salvati su macchine diverse, o sulla stessa macchina ma in file system separati, oppure sullo stesso file system ma non sullo stesso disco). In questi casi è necessario decidere come _partizionare_ i dati

- *Replicazione e sharding*: nel caso in cui i dati siano memorizzati su *sistemi diversi* è necessario decidere cosa e dove _replicare_ i dati, questo è un aspetto comune a praticamente tutte le diverse famiglie di database

- *Gestore della consistenza*: si occupa di fare in modo che tutte le repliche di uno stesso dato salvate su uno o diversi sistemi siano tra loro consistenti

- *Esecuzione distribuita*: per consentire ai sistemi di essere il più efficienti possibili, nel momento in cui le informazioni sono salvate in maniera frammentaria, è possibile sfruttare il calcolo distribuito in parallelo, in modo da abbattere i costi di esecuzione

- *Gestione dei dati in streaming*

- *Code di messaggi*: si tratta di un meccanismo pensato ad hoc per la gestione di esecuzione distribuita e dei dati in streaming

== Database Management System Relazionali
Tutti i database relazionali sono basati sul *modello dei dati relazionale*. Andiamo di seguito a definirne le varie peculiarità:

- Un database è un _insieme di tabelle_ ognuna delle quali è caratterizzata da un *nome* che nello specifico è chiamato *relation symbol*
- L'intestazione della relazione va ad identificare i nomi delle _colonne_ che nello specifico sono chiamati *attribute names* insieme al _dominio_ dal quale ciascun attributo può prendere valore
- L'insieme delle _righe_ (*tuple*) di una tabella ne vanno a definire il contenuto

Di seguito vedremo le definizioni di *schema relazionale* e *schema della base di dati* con alcuni esempi per meglio comprendere questi concetti fondamentali.

#definition(title: "Schema Relazionale")[
  È possibile definire lo *schema relazionale* di una base di dati tramite i seguenti oggetti:

  - Simbolo di relazione $R$
  - Insieme degli attributi $A_1, ..., A_n$
  - Insieme delle dipendenze locali $Sigma_R$

  Possiamo unire gli oggetti di cui sopra tramite la seguente formula:
  $
    R = ({A_1, ..., A_n}, Sigma_R)
  $
]<def:relational_schema>


Di seguito possiamo osservare la come lo schema relazionale possa essere visto dal punto di vista di una tabella:
#table(
  columns: (auto, auto, auto, auto),
  inset: 10pt,
  align: center,
  table.header(
    [Simbolo di relazione #text(fill: green)[$R$]],
    [Attributo #text(fill: blue)[$A_1$]],
    [Attributo #text(fill: blue)[$A_2$]],
    [Attributo #text(fill: blue)[$A_3$]],
  ),
  [tupla #text(fill: orange)[$t_1$]],
  [#text(fill: orange)[$v_11$]],
  [#text(fill: orange)[$v_12$]],
  [#text(fill: orange)[$v_13$]],

  [tupla #text(fill: red)[$t_2$]], [#text(fill: red)[$v_21$]], [#text(fill: red)[$v_22$]], [#text(fill: red)[$v_23$]],
)

#pagebreak()
#example-box("Modello relazionale", [
  Di seguito mostriamo un'istanza del modello relazionale precedentemente illustrato:

  #align(center)[
    #table(
      columns: (auto, auto, auto, auto),
      inset: 10pt,
      align: center,
      table.header(
        [#text(fill: green)[BookLending]],
        [#text(fill: blue)[BookID]],
        [#text(fill: blue)[ReaderID]],
        [#text(fill: blue)[ReturnDate]],
      ),
      [], [#text(fill: orange)[123]], [#text(fill: orange)[225]], [#text(fill: orange)[25-10-2016]],
      [], [#text(fill: red)[234]], [#text(fill: red)[347]], [#text(fill: red)[31-10-2016]],
    )
  ]])

#definition(title: "Schema della Base di Dati")[
  È possibile andare a definire lo *schema della base di dati* tramite i seguenti oggetti:

  - Simbolo della base di dati $D$
  - Insieme di schemi relazionali $R_1, ..., R_m$
  - Insieme di dipendenze globali $Sigma$

  Possiamo unire gli oggetti di cui sopra tramite la seguente formula:

  $
    D = ({R_1, ..., R_m}, Sigma)
  $
]<def:database_schema>



#set math.equation(numbering: none)
#example-box(
  "Schema di una Base di Dati",
  [
    - Schema relazionale 1:
    $
      #text[Book] = ({#text[BookID, Author, Title]}, Sigma_#text[Book])
    $
    - Schema relazionale 2:
    $
      #text[BookLending] = ({#text[BookID, ReaderID, ReturnDate]}, Sigma_#text[Book])
    $
    - Schema relazionale 3:
    $
      #text[Reader] = ({#text[ReaderID, Name]}, Sigma_#text[Reader])
    $
    - Schema della base di dati:
    $
      #text[Library] = ({#text[Book, BookLending, Reader]}, Sigma)
    $
  ],
)

#set math.equation(numbering: "(1)")

Sia in #ref(<def:relational_schema>) che in #ref(<def:database_schema>) compare la nozione di *dipendenza*; è però necessario chiarire le differenze tra queste:

- quando il concetto di dipendenza compare con un pedice, per esempio $Sigma_R$, ci stiamo riferendo a *dipendenze intra-relazionali*; cioè che si verificano all'interno di una tabella.

Un esempio di dipendenze intra-relazionali sono le _dipendenze funzionali_, più in particolare le dipendenze indotte da attributi _chiave_: BookID #sym.arrow BookID, Author, Title è una dipendenza funzionale all'interno della relazione Book

- quando le dipendenze compaiono senza pedice, significa che sono *globali*, anche dette *inter-relazionali*

Un esempio di queste dipendenze sono _dipendenze di inclusione_ su particolari chiavi esterne: BookLending.BookID #sym.subset.eq Book.BookID o ancora BookLending.ReaderID #sym.subset.eq Reader.ReaderID.

=== Progettazione di una Base di Dati
Una volta presi in esame la situazione da rappresentare e i requisiti da questa richiesti, è possibile iniziare con la progettazione della base di dati. Dal momento che molti contesti presentano molte complicazioni e requisiti specifici, è bene avere un quadro il più generale possibile di ciò che si renderà necessario implementare; per questo motivo possiamo dividere la progettazione di un database in tre fasi fondamentali:

- definizione di un *modello concettuale*: serve a modellare ad alto livello la situazione presa in esame; tipicamente vengono impiegati i diagrammi entità-relazione.
  #figure(
    image("../images/ch01/dbms_interactions.png"),
    caption: [Diagramma Entità-Relazione di una libreria],
  )

  #v(2em)
- _traduzione_ dello schema relazionale in un *modello logico*: il processo da seguire per la traduzione è piuttosto semplice e standard; infatti tipicamente ogni entità viene di solito mappata in una relazione, così come ogni relazione, in base alla sua cardinalità può essere tradotta in maniera differente

Alcuni design per una base di dati possono essere problematici. Di seguito andiamo ad indicare alcune forme di inconsistenza che possono presentarsi:

- Alcune tabelle potrebbero contenere troppi valori, o addirittura valori *duplicati*
- Potrebbero verificarsi anomalie nel momento in cui andiamo a manipolare i dati:
  - *Anomalie di inserimento*: nel momento in cui andiamo ad inserire i dati abbiamo bisogno di tutti i valori ma alcuni potrebbero essere ancora sconosciuti
  - *Anomalie di cancellazione*: nel momento in cui andiamo a cancellare una tupla, potremmo andare a cancellare informazioni di cui abbiamo ancora bisogno in altri record di altre relazioni
  - *Anomalie di aggiornamento*: quando i dati sono memorizzati in maniera ridondante, questi devono essere modificati per tutte le loro occorrenze

Le problematiche e le anomalie sopra elencate sono tipicamente ammortizzate applicando tecniche di *normalizzazione* della base di dati. L'obiettivo della normalizzazione è quello di distribuire i dati in maniera omogenea tra le tabelle. In base al tipo di normalizzazione che andiamo a garantire riusciamo a prevenire diversi tipi di anomalia:

- *1° Forma Normale*: non vengono ammessi attributi multivalore o composti
- *2° Forma Normale*: tutti gli attributi non chiave sono completamente dipendenti dagli attributi chiave, in altre parole non deve esistere un sottoinsieme degli attributi chiave che può essere usato per derivare attributo non chiave
- *3° Forma Normale*: tutti gli attributi non chiave sono direttamente dipendenti dagli attributi chiave, in altre parole si dice che non sono ammesse dipendenze transitive
- *4°, 5° Forma Normale* e *Forma Normale di Backus-Naur* sono altri tipi di forma normale ma non così comuni e comunque fuori dallo scopo di questo corso

=== Query Relazionali
Una volta che i dati sono memorizzati all'interno della nostra base di dati, possiamo chiederci in quale modo ottenere informazioni da questi. A questo scopo abbiamo a disposizione degli strumenti che sono noti con il nome di *query*.

Le query sono strumenti che ci consentono di effettuare diversi tipi di operazioni sui dati:

- Specificare condizioni per selezionare solo tuple rilevanti
- Restringere tabelle ad un sottoinsieme di attributi
- Combinare valori provenienti da diverse tabelle

Esistono diversi linguaggi per effettuare query a una base di dati: _calcolo relazionale_, _algebra relazionale_, _SQL_. Di seguito andiamo ad elencare alcuni operatori dell'algebra relazionale:

- *Proiezione* $pi$: utilizzata per restringere una tabella ad un sottoinsieme di attributi
- *Selezione* $sigma$: utilizzata per selezionare solo alcune tuple di una tabella
- *Rinominazione* $rho$: utilizzata per cambiare nomi ad un attributo
- *Operazioni insiemistiche*: unione #sym.union, differenza #sym.minus, intersezione #sym.inter
- *Join naturale* #sym.join: utilizzato per combinare due tabelle sulla base di attributi comuni
- *Operatori di join avanzati* come #sym.theta - join, equi-join, ...

Le query relazionali,che si possono vedere come una catena di applicazioni di opperatori relazionali, possono essere visualizzate in strutture ad albero, questo tipo di visualizzazione porta con se alcuni vantaggi:

- Mostra l'ordine di valutazione di ogni operazione
- È utile nel contesto dell'ottimizzazione delle query

// Definisco l'albero di sinistra usando la sintassi #sym
#let tree-left = canvas({
  import draw: *

  set-style(content: (padding: 0.5em))
  tree.tree(
    (
      $pi_#text[Name]$,
      (
        $sigma_#text[Return date < 20/10/2016]$,
        (
          [#sym.join],
          (
            [Reader]
          ),
          (
            [BookLending]
          ),
        ),
      ),
    ),
  )
})

#let tree-right = canvas({
  import draw: *

  set-style(content: (padding: 0.5em))
  tree.tree(
    (
      $pi_#text[Name]$,
      (
        [#sym.join],
        (
          [Reader]
        ),
        (
          $sigma_#text[ReturnDate < 20/10/2016]$,
          [BookLending],
        ),
      ),
    ),
  )
})

#example-box(
  "Alberi equivalenti per una query che lista il nome di tutti i lettori dei libri prestati che abbiano ReturnDate < 20/10/2016",
  [
    // Dispongo i due alberi in una figura con didascalia
    // Questa parte è già 100% Typst e non "sembra LaTeX"
    #figure(
      grid(
        columns: (1fr, 1fr),
        // Due colonne di uguale larghezza
        gutter: 2em,
        // Spazio tra le colonne
        align: center,
        // Centra gli alberi nelle colonne

        tree-left, tree-right,
      ),
      caption: [Due diversi piani di query per la stessa richiesta in algebra relazionale.],
    )<fig:algbratreecomparison>
  ],
)

Possiamo osservare come #ref(<fig:algbratreecomparison>) illustri due modi alternativi di eseguire la stessa query relazionale. Osservando attentamente l'ordine tra _join_ e _selezione_, è possibile notare che nell'albero di destra otteniamo una query più efficiente, dal momento che ci troveremo a effettuare un join dove una delle due tabelle da unire è stata prima filtrata. In questo modo ci troveremo a dover effettuare un confronto con molti meno record rispetto alla rappresentazione di sinistra.

=== Transazioni e Gestione della Concorrenza
Quando andiamo a modificare i dati all'interno di una base di dati, possiamo andare incontro a diverse tipologie di problematiche. Di seguito andiamo ad elencarne alcune:

- *Integrità logica dei dati*: dobbiamo assicurarci che tutti i valori scritti siano corretti e che siano effettivamente il risultato atteso dall'esecuzione di un'operazione
- *Integrità fisica e recovery*: dobbiamo garantire la persistenza dei dati assieme alla possibilità di recuperarli nel caso in cui si verifichino dei crash di sistema
- *Gestione di più utenti*: dobbiamo permettere agli utenti di operare in maniera concorrente sulla stessa base di dati senza che ci siano interferenze

Tutte le questioni sopra elencate possono essere indirizzate tramite l'impiego di *transazioni*.

#definition(title: "Transazione")[
  Una *transazione* è una sequenza di operazioni di _lettura e scrittura_ su una base di dati con le seguenti proprietà:

  - Deve essere trattata come *entità atomica* di esecuzione
  - Deve portare la base di dati da uno stato consistente ad un nuovo stato anch'esso consistente
]

L'esempio più tipico di una transazione è quello di un trasferimento di denaro da un conto bancario ad un altro. Di seguito specifichiamo alcune delle proprietà che le basi di dati devono rispettare affinché possiamo affermare che gestiscano le transazioni correttamente:

- *Atomicità*: data una transazione possiamo eseguire tutte le operazioni di questa, oppure nessuna, non è possibile eseguire una transazione in modo _parziale_
- *Consistenza*: dopo l'esecuzione di una transazione tutti i valori nella base di dati devono essere corretti rispetto ai vincoli e alle dipendenze intra-inter relazionali
- *Isolamento*: transazioni concorrenti di utenti differenti non devono interferire tra loro
- *Durabilità*: è necessario che i risultati di una transazione rimangano persistenti anche a seguito di possibili crash di sistema. Per garantire questa proprietà di solito si utilizza un *transaction log*, nel quale tutte le transazioni vengono registrate

Le proprietà sopra elencate sono anche dette *ACID*, utilizzando le loro iniziali per formare l'acronimo.

=== Problematiche del Modello Relazionale
L'impiego di modelli relazionali può portare con sé alcune problematiche dovute intrinsecamente a come vengono impiegate tabelle e relazioni. Andiamo ad elencare alcune problematiche di seguito:

- *Overloading semantico*: il modello relazionale rappresenta sia entità che relazione tramite l'utilizzo di _tabelle_, non esiste infatti in modo per rappresentare separatamente i due concetti
- *Struttura dati omogenea*: il modello relazionale assume omogeneità sia orizzontale che verticale. L'omogeneità orizzontale implica che tutte le tuple hanno valori per gli stessi attributi; quella verticale si riferisce al fatto che, data una colonna, i suoi valori provengono tutti dallo stesso dominio. Inoltre ogni cella può contenere soltanto valori atomici, il che potrebbe risultare limitante in alcuni contesti
- *Supporto limitato alla ricorsione*: è molto complicato andare a definire query ricorsive in SQL; nel caso ad esempio in cui ci trovassimo a dover lavorare su strutture a grafo sarebbe veramente complicato utilizzare un modello relazionale

== Nuovi Requisiti
Dopo aver descritto in maniera approfondita tutte le peculiarità di SQL e del modello relazionale che va ad implementare, spostiamo la nostra attenzione su dei _nuovi requisiti_ che situazioni odierne ci portano a dover soddisfare.

Il primo di questi è sicuramente legato a dati che hanno bisogno di essere organizzati in *strutture* sempre più *complesse* come ad esempio nei social network.

Se un tempo le operazioni di lettura erano molto più frequenti rispetto alle operazioni di scrittura, il mondo moderno e l'utilizzo di nuove tecnologie ci pongono davanti ad un cambio di paradigma dove spesso è anche necessario andare a *scrivere* *in maniera* *frequente* sulle nostre basi di dati.

Dal momento che il mondo contemporaneo è sempre più _data-centric_, è necessario dover gestire una quantità sempre maggiore di dati, il che sarebbe impossibile utilizzando una singola macchina, rendendo necessario *distribuire i dati* su molti server interconnessi (_cloud storage_).

Tutte le esigenze di sopra aprono la strada all'utilizzo di un nuovo approccio, quello *NoSQL*, nel quale alcune proprietà e garanzie del modello relazionale vengono trascurate al fine di provare a soddisfare in maniera migliore i nuovi requisiti. Di seguito elenchiamo alcune delle differenze tra gli approcci NoSQL e il tradizionale SQL:

- Il modello dei dati potrebbe essere diverso da quello tradizionale basato sulle tabelle
- Accesso programmatico alla base di dati  o con strumenti diversi da SQL
- Capacità di gestire modifiche allo schema dei dati
- Capacità di gestire dato senza uno schema specifico
- Supporto alla distribuzione dei dati
- Requisito di aderenza alle proprietà ACID che viene alleggerito, specialmente in termini di consistenza, rispetto ai DBMS tradizionali
