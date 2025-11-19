
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


= Architetture per Basi di Dati
Questo capitolo dà inizio alla seconda parte del corso. Tutto ciò che tratteremo da questo momento in poi supporrà che il punto di partenza sia quello di un *java relational system*. La struttura di base di tale elemento è quella che è già stata presentata in @fig:rdbms_internal, che per completezza viene di seguito riportata.


#align(center)[
  #image("../images/ch03/rdbms_internal.png", width: 75%)
]

La scelta di considerare questa architettura viene fatta per semplicità, e per la maggiore familiarità che si ha tipicamente con una base di dati relazionale. Tuttavia, è importante considerare che la maggioranza delle famiglie di database già presentate condivide la gran parte delle componenti con questa architettura.

Come già menzionato l'architettura presentata può essere rappresentata in *due blocchi*

- un blocco che presenta delle componenti specifiche alla famiglia di database che abbiamo scelto di utilizzare, che in questo caso è il *relational engine*
- un blocco che è deputato alla gestione della memorizzazione e il recupero dei dati in memoria principale, a cui ci si riferisce tipicamente con il nome di *storage engine*

Questo schema a blocchi non è sempre presente, esistono casi in cui lo storage engine viene fuso alla componente che normalmente dovrebbe essere più specifica al tipo di dati che vogliamo rappresentare nella nostra base di dati.

In linea di massima però relational (o document database, ...) e storage engine sono tra loro _indipendenti_. Questo maggiore livello di astrazione ci consente di trattare in maniera separata il modo in cui vengono rappresentati a livello logico i dati dal modo in cui questi vengono effettivamente trattati all'interno della memoria secondaria.

Nel corso del capitolo procederemo a presentare le varie componenti seguendo un approccio *bottom-up*, partendo dunque dallo storage engine. Dal momento che non si tratta di componenti fondamentali per il funzionamento di una base di dati, eviteremo di trattare, per ora, il gestore delle transazioni, del recovery e della concorrenza. Andremo dunque a concentrarci sulla colonna centrale dello storage engine.

Vedremo inoltre come questo stack di componenti sia molto simile nel concetto allo stack ISO/OSI, dove ogni componente fornisce servizi per il componente di livello superiore e ne utilizza dal livello inferiore, fino ad arrivare al livello più basso possibile.

== Persistent Memory Manager
Come già menzionato in qualche capitolo precedente il principale ruolo del gestore della memoria persistente è quello di fornire un'*astrazione linearmente indirizzabile* della memoria, nascondendo ai livelli superiori l'effettiva struttura della memoria.

Tipicamente vengono utilizzati più *livelli di memoria* in maniera molto simile a quanto accade all'interno di un normale calcolatore. A taglie di memoria più grande, corrisponderà maggior latenza, mentre man mano che si diminuisce la capacità si va a migliorare il tempo di accesso ai dati. Tipicamente i livelli che troviamo in ambienti production scale:

- _glacier storage_: utilizzati per storage di dati a lunghissimo termine
- _data lakes_: utilizzati per memorizzare oggetti usati più frequentemente
- _cloud storage / network drives_: basati su file system distribuiti remotamente
- _drive locali_: dispositivi locali tipicamente accessibili all'interno di una stessa rete
- _gerarchia di memoria del calcolatore_

Ciò che differenzia i vari tipi di memoria è che ad un certo punto della gerarchia esiste una sorta di 'barriera' dalla quale in poi tutto quanto ciò che memorizziamo è volatile. Tipicamente questa soglia è costituita dalla *memoria principale*.

=== Geometria di un Hard Disk
Per quanto possa sembrare poco attuale parlare della geometria di un disco magnetico in questo periodo storico, è importante sottolineare che questo tipo di supporto ha una caratteristica molto conveniente rispetto ad un SSD. Oltre al costo che è indubbiamente minore, ciò che è più importante è il fatto che questo tipo di supporti *non degrada* nel tempo.

È noto infatti che tecnologie come gli SSD sono altamente soggette ad *isteresi*, quel fenomeno per cui lo stato di una porzione della memoria non è più dipendente dai dati memorizzati in un certo momento, ma anche dalla storia di tutti i dati memorizzati in quella porzione di memoria. Questo rende, dopo una certa quantità di tempo, un disco a stato solido inutilizzabile. Sebbene all'interno di un personal computer questo fenomeno possa essere trascurabile, in una base di dati, dove si rende necessario scrivere e leggere dati in maniera intensiva, questo processo potrebbe notevolmente amplificarsi.

All'interno di un supporto magnetico possiamo identificare le seguenti componenti:

- *Tracce*: percorsi circolari su un disco
- Ogni traccia è divisa in *settori* che vanno da 512 a 4KB
- Ogni traccia è composta da un numero variabile di settori, trai 500 e i 1000
- Un *cilindro* è composto da un insieme di tracce che si trova nella stessa posizione relativamente alla testina.

Su tutta la superficie del disco abbiamo circa 100k traccie. Per quanto tutte le tracce abbiano una dimensione fisica differente, queste hanno tutte la *stessa capacità di memorizzazione*. Tracce di dimensione minore conterranno informazione in maniera più densa di altre tracce a dimensionalità maggiore.

Ogni traccia è divisa *logicamente* in *blocchi* di dimensione fissa, che rappresentano i blocchi di trasferimento trai vari livelli di memoria.

#figure(
  image("../images/ch07/01_magnetic_disk.png", width: 50%),
  caption: "Rappresentazione schematica di un disco magnetico",
)

=== Lettura da Disco Magnetico
Nel momento in cui andiamo a leggere dei dati da un disco magnetico dobbiamo tenere in considerazione i seguenti aspetti:

- è necessario trasformare l'indirizzo lineare in un *indirizzo fisco*
- una volta trovato il l'indirizzo fisico _muoviamo la testina_ sul *cilindro* di competenza
- una volta trovato il cilindro, andiamo a muovere la testina per farla finire sul *settore* corretto della traccia di interesse

Tutte queste operazioni hanno un costo che possiamo rappresentare tramite la seguente formula:

#math.equation(
  block: true,
  $text("Block Access Time") = t_s + t_r + t_b$,
)

dove:

- $t_s$ sta per il *seek time*, ovvero il tempo necessario per muovere la testina sul cilindro corretto (3.5/4 ms in media)
- $t_r$ sta per il *rotational latency*, ovvero il tempo necessario per far arrivare il settore corretto sotto la testina (2 ms in media)
- $t_b$ sta per il *transfer time*, ovvero il tempo necessario per trasferire i dati dal disco alla memoria principale (0.1 ms per 4KB circa)

Evidentemente il tempo di trasferimento di un blocco dati è dominato da latenza e seek time. Per questo motivo, invece che andare a leggere un singolo blocco alla volta, è preferibile leggere più blocchi in sequenza (*pagine*), in modo da minimizzare il numero di seek e rotazioni. Questo fenomeno rende molto importante il concetto di *località spaziale*:

- per trasferire un blocco il tempo necessario è $t_s + t_r + t_b$
- per trasferire $n$ blocchi in sequenza il tempo necessario è $t_s + t_r + n dot t_b$


== Buffer Manager
Come già anticipato, l'unità di misura per il trasferimento dei dati all'interno dei supporti di memorizzazione è quella delle *pagine*. Il compito del gestore del *buffer* è proprio quello di spostare pagine _tra la memoria permanente_ e quella _principale_.

Nel fare questo fornisce una *vista logica* della memoria persistente sotto forma di pagine che possono essere utilizzate in memoria principale. I suoi obiettivi sono i seguenti:

- *limitare* il più possibile *letture* *ripetute* di una stessa pagina
- *minimizzare* il numero di *accessi* in *scrittura*

La porzione di memoria gestita dal buffer manager viene chiamata *buffer pool*. Tipicamente questi buffer possono essere molto grandi e risiedono in memoria principale. Il meccanismo che governa il funzionamento del buffer pool è estremamente simile a quello in uso nei sistemi operativi per la gestione della memoria virtuale o di una cache.


=== Bozza di Interfaccia del Buffer Manager
Di seguito viene presentato un insieme di operazioni che un buffer manager dovrebbe essere in grado di fornire come interfaccia sulla quale costruire il resto del sistema.

==== `GB_getAndPinPage(pageID) --> Page`
Si tratta di un'operazione fondamentale per l'effettiva lettura di una pagina: recupera la pagina con identificativo `pageID` dalla memoria persistente spostando la pagina dalla memoria permanente al buffer. L'operazione di *pinning* consente nel rappresentare l'informazione che la pagina è in uso, non si tratta di un flag, quanto più di un contatore che tiene traccia di quante entità stanno utilizzando la pagina.

==== `GB_setDirty(pageID)`
Questa operazione è fondamentale nel momento in cui andiamo a modificare dati all'interno di una pagina gestita nel buffer pool. Segnala che la pagina con identificativo `pageID` è stata modificata in memoria principale e deve essere scritta nuovamente su memoria permanente prima di essere rimossa dal buffer.

==== `GB_unpinPage(pageID)`
Quando abbiamo terminato di utilizzare una pagina, possiamo fare in modo che questa, a discrezione del del buffer, possa essere rimossa dalla porzione di memoria di sua competenza. Segnala che la pagina con identificativo `pageID` non è più in uso per una certa risorsa diminuendone il contatore di pinning. Se il contatore di pinning arriva a zero, la pagina può essere rimossa dal buffer pool.

==== `GB_flushPage(pageID)`
Questa operazione serve nel momento in cui vogliamo forzare la scrittura di una pagina su memoria permanente. Scrive la pagina con identificativo `pageID` su memoria permanente se questa è stata segnalata come *dirty*.

==== `GB_getNewPage(Field,Type) --> Page`
Alloca una nuova pagina all'interno della memoria permanente e la porta in memoria principale. La pagina viene inizializzata in base al tipo di dati che deve contenere.

=== Buffer Pool
Come già anticipato, il principale componente di competenza del gestore del buffer è il *buffer pool*. @fig:0702_bufferpool presenta una rappresentazione schematica di un buffer pool.

#figure(
  image("../images/ch07/02_bufferpool.png", width: 70%),
  caption: "Rappresentazione schematica del buffer pool",
)<fig:0702_bufferpool>

Possiamo notare come le funzioni di gestione del buffer siano rese disponibili all'esterno del buffer manager tramite un'interfaccia.
Possiamo notare come il buffer pool sia composto da un insieme di *frame* di dimensione fissa, tipicamente della stessa dimensione di una pagina. Ogni frame può contenere una pagina che è stata portata in memoria principale dalla memoria permanente. Ogni frame contiene inoltre delle informazioni di *metadati* che servono al buffer manager per tenere traccia dello stato della pagina contenuta al suo interno:

- un *contatore di pinning* che tiene traccia di quante entità stanno utilizzando la pagina
- un flag *dirty* che segnala se la pagina è stata modificata in memoria principale
- un campo *pageID* che identifica in maniera univoca la pagina contenuta all'interno del frame

==== Scrittura di Pagine su Memoria Permanente
Oltre che tramite l'API di flushing, è possibile che una pagina venga scritta in memoria permanente nel momento in cui, avendo il contatore di pinning a zero, il buffer manager decide di rimuoverla dal pool per fare spazio ad una nuova richiesta. In questo caso, se la pagina è segnalata come dirty, questa viene scritta in memoria permanente prima di essere rimossa dal buffer pool.

==== Out of Memory Error
Nel caso in cui il buffer pool sia pieno e venga richiesta una nuova pagina, il buffer manager deve decidere quale pagina rimuovere per fare spazio alla nuova richiesta. Tipicamente ciò che viene fatto è cercare una pagina con contatore di pinning a zero, e tra queste sceglierne una. Nel momento in cui non fosse presente nessuna pagina con contatore di pinning a zero, il buffer manager non sarebbe in grado di soddisfare la richiesta e e verrebbe segnalato un errore del tipo *out of memory*.

=== Tabella delle Pagine Residenti
Una componente fondamentale per il funzionamento del buffer manager è la *tabella delle pagine residenti* (resident page table). Si tratta di una struttura dati che consente di tenere traccia di quali pagine sono attualmente presenti all'interno del buffer pool.

Mentre sul disco le pagine sono identificate da un indirizzo fisico, il *pageID*, all'interno del buffer pool le pagine potrebbero essere assegnate in maniera _dinamica_ a diversi frame. La tabella delle pagine residenti consente di tenere traccia di questa associazione tra `pageID` e frame del buffer pool. @fig:0703_residentpagetable presenta una rappresentazione schematica della tabella delle pagine residenti.

#figure(
  image("../images/ch07/03_residentpages.png", width: 70%),
  caption: "Rappresentazione schematica della tabella delle pagine residenti",
)<fig:0703_residentpagetable>


==== Gestione di una richiesta di una pagina
Di seguito andiamo a mostrare il flusso operativo che avviene all'interno del buffer manager nel momento in cui si rende necessario gestire la richiesta di una pagina:

- Se la pagina è già presente nel buffer pool, andiamo semplicemente ad incrementare il pin count ritornandone il riferimento al richiedente
- Se la pagina non è presente procediamo come di seguito:
  - Scegliamo una frame libero, o una frame dove il pin count sia zero tramite l'utilizzo di una *politica di sostituzione*. Se tale pin count è zero, e la pagina è dirty, procediamo a scriverla su memoria permanente
  - Carichiamo la pagina richiesta dalla memoria permanente alla frame scelta, impostando il pin count a 1 e il flag dirty a false
  - Aggiorniamo la tabella delle pagine residenti ritornando al chiamante il riferimento alla pagina appena caricata

==== Politica di Sostituzione
Nel momento in cui si rende necessario scegliere una pagina da rimuovere dal buffer pool, il buffer manager deve adottare una *politica di sostituzione* per scegliere quale pagina rimuovere.

La possibilità più semplice è quella di utilizzare un approccio *LRU*. Questo approccio è particolarmente adatto alla situazione in cui dobbiamo effettuare un `JOIN`, tuttavia non è detto che sia sempre la scelta ottimale. In alcuni caso *MRU* potrebbe essere una scelta migliore.

Nel caso in cui avessimo degli indici, allora potremmo aver bisogno di applicare politiche di sostituzione più sofisticate, che meglio si adattano al tipo di accesso che stiamo effettuando sui dati. In questo caso avremo però bisogno di utilizzare un *buffer pool separato* da quello normale per gestire le pagine degli indici, in modo da poter applicare politiche di sostituzione differenti.

=== Struttura di una Pagina di Memoria
Abbiamo già visto come l'unità di trasferimento dei dati tra memoria principale e secondaria sia la *pagina*. Fino a questo momento abbiamo soltanto visto come una pagina sia caratterizzata da un identificativo univoco.

Da un punto di visto *fisico* (all'interno di un file, che ricordiamo essere un insieme di pagine) una pagina è una struttura dati di *dimensione fissa*. Dal punto di vista *logico* (all'interno di un buffer) una pagine è una struttura che contiene le seguenti informazioni:

- *informazioni di servizio*: metadati necessari per la gestione della pagina all'interno del buffer pool
- *record*: i dati veri e propri memorizzati all'interno della pagina

Ora che abbiamo intuito come lo scopo di una pagina è quello di contenere diversi record, è necessario capire come effettuare accesso ai vari record. Abbiamo già citato in capitoli precedenti come ogni record sia fatto da *campi* (fields). Ognuno di questi campi può essere memorizzato in modo diverso:

- *dimensione fissa*: per esempio potremmo allocare un certo numero di byte per memorizzare certi valori. In questo caso l'accesso ai campi è molto semplice, in quanto basterà conoscere l'offset del campo all'interno del record per poterlo recuperare. Tuttavia questo approccio, nel caso di dati con dimensione variabile, potrebbe portare a sprechi di spazio, in quanto potremmo allocare più spazio del necessario
- *separatore speciale*: potremmo scegliere di utilizzare un carattere special per separare i valori all'interno di un record
- utilizzo di un *prefisso* che indica la *lunghezza del campo*

Tipicamente è presente una corrispondenza univoca tra record e pagine: ogni record è contenuto in una sola pagina. Tuttavia, ci sono dei casi, per esempio con dati in formato `BLOB`, in cui un singolo record potrebbe essere più grande della dimensione di una pagina. Per gestire questo caso avremo bisogno di una _sovrastruttura_ che andremo a introdurre più avanti nel corso. L'idea è quella di memorizzare in record in un contenitore sufficientemente grande e memorizzare un riferimento a questo contenitore.

#example-box("Memorizzazione di record con campi a dimensione fissa", [
  Si consideri la seguente tabella rappresentante un record  con diversi campi ognuno con diverse dimensioni ma memorizzati con delle dimensionalità fisse.
  #align(center)[
    #table(
      columns: (auto, auto, auto, auto),
      inset: 10pt,
      align: center,
      table.header([*Attributo*], [*Posizione*], [*Tipo del Valore*], [*Valore*]),

      [Name], [1], [`char(10)`], [Rossi],
      [StudentCode], [2], [`char(6)`], [456],
      [City], [3], [`char(2)`], [MI],
      [BirthYear], [4], [`int(2)`], [68],
    )
  ]

  In questo caso il numero totale di caratteri utilizzato effettivamente sarà 20. Di seguito mostriamo come sia possibile memorizzarlo secondo i vari approcci presentati sopra:

  - _Dimensione fissa_: `Rossi....456...MI68`
  - _Separatore speciale_: `Rossi|456|MI|68|`
  - _Indice_ che indica l'inizio di ogni campo: `(1,6,9,11)Rossi456MI68`
])

Per fare *riferimento* ad un *record* utilizziamo un identificativo univoco chiamato *record identifier*, che è composto da due campi:

- un *pageID* che identifica la pagina in cui il record è memorizzato
- un *offset* che indica la posizione del record all'interno della pagina

L'utilizzo di questi record identifier è particolarmente utile nel momento in cui andiamo ad utilizzare degli *indici* per velocizzare l'accesso ai dati.

Quello appena presentato, chiamato *riferimento diretto*, non è però il modo migliore per fare riferimento a record. Immaginiamo infatti di star indicizzando un insieme di record che si possono trovare su più pagine, e l'indice punta al riferimento diretto di ogni record. Se andiamo ad eliminare dei record in una pagina potremmo potremmo a un certo punto aver bisogno di _deframmentare_ la pagina per recuperare spazio. In questo caso, i riferimenti diretti all'interno dell'indice andrebbero a puntare a posizioni errate. Ricalcolare l'indice sarebbe estremamente costoso.

Per questo motivo si preferisce mantenere un livello di *indirezione* tra l'indice e il record vero e proprio. In questo caso l'indice punterà ad un elemento dello *slot array* che sarà una struttura presenta a livello di pagina. Sarà poi compito dello slot array tenere traccia del riferimento diretto (che in termini pratici, consiste solamente nell'_offset_) di ogni record. In questo modo, nel momento in cui andiamo a deframmentare la pagina, sarà sufficiente aggiornare lo slot array senza dover toccare l'indice.

Lo slot array viene posizionato tipicamente alla fine della pagina, in modo da poter crescere verso l'alto. Se andassimo infatti a posizionare questo elemento all'inizio della pagina, ogni elemento aggiunto potrebbe farlo crescere di dimensionalità, comportando una nuova modifica di tutti gli offset.

#figure(
  image("../images/ch07/04_slot_array.png", width: 80%),
  caption: "a) Rappresentazione di utilizzo di riferimenti diretti per i record all'interno di una pagina. b) Rappresentazione di utilizzo di uno slot array per i record all'interno di una pagina.",
)<fig:0704_pagesttructure>
