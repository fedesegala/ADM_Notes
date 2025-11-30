
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

È importante andare a vedere come la memoria secondaria sia strutturata, questa informazione sarà estremamente utile per comprendere anche le sezioni successive. Possiamo dire in generale che la memoria permanente di una DBMS è organizzata a livello logico come un insieme di 'database', ognuno di questi si può vedere come un *insieme di file*, che a loro volta sono organizzati in *pagine* linearmente indirizzabili

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

Per questo motivo si preferisce mantenere un livello di *indirezione* tra l'indice e il record vero e proprio. In questo caso l'indice punterà ad un elemento dello *slot array* che sarà una struttura presenta a livello di pagina. Sarà poi compito dello slot array tenere traccia del riferimento diretto (che in termini pratici, consiste solamente nell'_offset_) di ogni record. In questo modo, nel momento in cui andiamo a deframmentare la pagina, sarà sufficiente aggiornare lo slot array senza dover toccare l'indice. @fig:0704_slotarray mostra schematicamente la differenza tra l'approccio indiretto e indiretto.


#figure(
  image("../images/ch07/04_slot_array.png", width: 80%),
  caption: "a) Rappresentazione di utilizzo di riferimenti diretti per i record all'interno di una pagina. b) Rappresentazione di utilizzo di uno slot array per i record all'interno di una pagina.",
)<fig:0704_slotarray>

#remark[
  Lo slot array viene posizionato tipicamente alla fine della pagina, in modo da poter crescere verso l'alto. Se andassimo infatti a posizionare questo elemento all'inizio della pagina, ogni elemento aggiunto potrebbe farlo crescere di dimensionalità, comportando una nuova modifica di tutti gli offset.
]

== Strutture per File Management
Come già noto dalla sezione del permanent memory manager, sappiamo che un *file* si può vedere dal punto di vista logico come un *insieme di pagine*.

Fino a questo momento ci siamo sempre concentrati sulla gestione dei record all'interno di una pagina. Abbiamo imparato come leggere dei record e come andarli a memorizzare all'interno di una pagina, dando per assunto di conoscere la pagina in cui i record sono memorizzati. Nella prossima sezione andremo a concentrarci su come venga gestito lo spazio all'interno di un file, che ricordiamo essere un insieme di pagine:

- come viene *scelto* dove memorizzare un nuovo record
- come *modificare* il contenuto di un *file* per riciclare memoria
- come *compattare* lo spazio all'interno di un *file*


In generale il tema di maggiore importanza è capire come *scegliere* una pagina sufficientemente capiente da poter memorizzare un nuovo record; sempre che questa pagina esista, in caso contrario sarà necessario allocare una nuova pagina all'interno del file.

In questa sezione andremo a vedere diversi approcci per la gestione dell'allocazione dello spazio all'interno di un file: _seriale_, _sequenziale_, _associativo_ (per attributi unici o non unici).

==== Modello di Costo
Prima di andare a vedere i vari modelli di allocazione dello spazio all'interno di un file, è importante definire un *modello di costo* che ci consenta di valutare l'efficacia dei vari approcci. Andremo a tenere in considerazione i seguenti aspetti:

- *spazio utilizzato*: quantità di spazio effettivamente utilizzato per memorizzare i record, specialmente nel caso in cui venga utilizzata memoria ausiliaria
- *performance*: numero di operazioni read/write necessario per eseguire determinate operazioni come inserimento, aggiornamento, cancellazione e ricerca

All'interno di questo modello di costo, considereremo un file $R$ con $N_("rec")$ record di lunghezza $L_r$ e un numero di pagine $N_("page")$ di dimensione $D_("page")$.

#remark[
  Si noti come tutti i parametri definiti nell'ultimo paragrafo siano *necessari* per poter valutare l'efficacia del nostro modello di allocazione.
]

In base alle informazioni fornite dal nostro modello di costo, avremo la possibilità di comprendere quale sia il modello di allocazione più adatto alle nostre esigenze. Tipicamente l'*unità di misura* tramite cui esprimiamo il costo è il numero di *accessi a pagina* necessari per eseguire una certa operazione (sia in lettura, sia in scrittura).

=== Modello Seriale e Sequenziale
È stato scelto di raggruppare questi due approcci per l'organizzazione dei file in quanto condividono molte caratteristiche. La loro peculiarità consiste nel fatto che entrambi gli approcci *non utilizzano strutture dati ausiliarie*, la memoria viene utilizzata solamente per tenere traccia delle pagine che compongono il file.

La differenza sostanziale trai due approcci consiste nel fatto che il modello *seriale* (_heap file_) non suppone alcun ordinamento dei valori all'interno del file, mentre il modello *sequenziale* suppone che i record siano memorizzati in ordine in base al valore di uno o più attributi.

==== Organizzazione Seriale
Il modello _heap file_ è una tecnica molto semplice ed efficiente in termini della memoria utilizzata. Il problema è che nel caso di file molto grandi potrebbe risultare in performance scadenti. È ottimale nel caso invece in cui i file gestiti siano di piccole dimensioni. Si tratta dell'organizzazione per file che viene utilizzata di default nella maggior parte dei DBMS. Di seguito andiamo a vedere come vengono gestite le varie operazioni sui file:

- *ricerca* di un singolo valore per un attributi: è necessario effettuare una scansione sequenziale fino a quando non viene trovato il valore cercato, o fino a quando la fine della lista non viene raggiunta
- *ricerca* di un *intervallo* di valori: similmente al caso precedente è richiesta una scansione completa. La differenza rispetto a prima è che abbiamo un 'stop criteria' differente, dal momento che dobbiamo continuare a leggere fino a quando non superiamo il valore massimo dell'intervallo
- l'*inserimento* di un nuovo record avviene semplicemente aggiungendo il record alla fine dell'ultimo file
- la *cancellazione* e l'*aggiornamento* di un record vengono effettuate tramite un'operazione di ricerca del record e di _riscrittura_.

==== Costi del Modello Seriale
Di seguito andiamo ad illustrare i vari costi associati all'utilizzo di una architettura di questo genere. In generale, in termini di *spazio* avremo bisogno di una quantità espressa dall'equazione di seguito:

#math.equation(
  block: true,
  numbering: "(1)",
  $
    N_("page")(R) = N_("rec")(R) dot L_r / D_("page")
  $,
)<eq:space_seriale>

#remark[Il valore di $L_r$ è tipicamente esatto, nel caso in cui abbiamo a che fare con valori provenienti da un dominio 'statico', nel caso in cui avessimo valori a lunghezza variabile, il suo sarà una media delle varie dimensioni memorizzate fino ad un certo punto.  ]

Possiamo notare come in @eq:space_seriale il costo in termini spazio sia unicamente dipendente dall'informazione memorizzata all'interno di un file. Andiamo ora ad osservare il costo in termini di numero accessi alle pagine per le varie operazioni:

- Per quanto riguarda *cancellazione* e *aggiornamento* avremo bisogno di un numero di accessi alle pagine pari a quello necessario per una ricerca più un accesso in scrittura per riscrivere il record: $C_d = C_u = C_s + 1$

Il motivo per cui il costo di una cancellazione di valore è uguale a quello di un aggiornamento è dovuto al fatto che, per evitare di dover spostare tutti i record cancellandone uno, si preferisce sovrascrivere il record o impostare un flag di cancellazione. In questo modo il costo risulta essere identico.

- per l'*inserimento* di un record avremo già conoscenza riguardo a quale sia l'ultima pagina del file, e potremo quindi effettuare una lettura della pagina di interesse e un conseguente inserimento: $C_i = 2$

- per la *ricerca* di un *singolo valore* per un attributo: $C_s approx ceil(N_("page")(R) / 2)$ mediamente nel caso in cui il valore sia presente, in caso contrario avremo $C_s = N_("page")(R)$

- per la *ricerca* di un *intervallo* di valori: $C_r = N_("page")(R)$, non essendo infatti i valori ordinati, si rende necessario scorrere l'intero file per essere sicuri di aver trovato tutti i valori nell'intervallo.

==== Organizzazione Sequenziale
L'idea alla base dell'organizzazione sequenziale è quella di mantenere i record ordinati rispetto ad una chiave $K$ e memorizzarli in memoria continua. Questo principio consente di abbassare notevolmente i costi di ricerca, sia per un singolo valore, sia per un intervallo di valori.

Lo svantaggio principale di questo approccio è legato al *mantenimento dell'ordinamento*. Questo comporta infatti che ogni inserimento e aggiornamento comporti una riorganizzazione del file, che potrebbe essere estremamente costosa. Nello specifico, le operazioni di aggiornamento sono ancora più complicate, dal momento che possono o non possono cambiare l'organizzazione del file a seconda del valore della chiave $K$.

Per tutte queste ragioni, l'utilizzo di questo modello di organizzazione, sebbene interessante dal punto di vista teorico, non viene praticamente mai utilizzato nei DBMS moderni. L'unico caso in cui risulti utile è quello in cui il file venga utilizzato in sola lettura, come per esempio nel caso di *data warehousing*.

===== Ricerca di un singolo valore
Nel momento in cui dobbiamo andare a cercare una determinata chiave $k$ all'interno di un file sequenziale, possiamo sfruttare l'ordinamento di questo. A livello teorico possiamo utilizzare tutti i possibili algoritmi già noti per la ricerca in liste ordinate, come per esempio la *ricerca binaria*.

#remark[Si rende necessario tenere in considerazione che i dati vengono trasferiti *una pagina alla volta* (o a blocchi di pagine). Questo porta ci porta ad adattare i nostri algoritmi di ricerca.]

Pensiamo ad esempio alla ricerca binaria in cui andiamo normalmente a scegliere un '_pivot_' e sulla base del valore di questo andiamo a decidere se cercare nella metà sinistra o destra della lista di valori. In questo caso non abbiamo più soltanto un 'pivot', ma ci servirà utilizzare '*pagine pivot*':

- Scegliamo una '_pagina pivot_' (tipicamente al centro del file) $P_i$, con $1 <= i <= N_("page")(R)$

- Prendiamo $m_i, M_i$ come rispettivamente il valore minimo e massimo dell'attributo cercato nella pagina $P_i$


- Se $m_i <= k <= M_i$ allora abbiamo trovato la pagina di nostro interesse e possiamo cercare $k$ al suo interno, in caso contrario se $k < m_i$ allora andiamo a cercare nella metà sinistra del file, altrimenti andiamo a cercare nella metà destra del file.

- Se l'intervallo di pagine da cercare è vuoto, allora il valore non è presente nel file

#remark[
  Si noti come il costo di ricerca di un valore all'interno di una pagina una volta che questa è stata trovata si può considerare *trascurabile*, dal momento che il costo totale (in termini di tempo e latenza) sarà dominato dal numero di accessi alle pagine.
]

#pagebreak()

=== Algoritmi di Ricerca e Costi
Di seguito andiamo a presentare varie possibilità per implementare la ricerca di un singolo valore all'interno di un file sequenziale andandone a valutare i costi associati.

===== Ricerca Binaria
Come noto da precedenti corsi di algoritmi, la ricerca binaria, che va a scegliere il '*pivot*' al *centro* dell'*intervallo di ricerca* in cui cercare produce un costo medio dato da:

#math.equation(
  block: true,
  numbering: none,
  $
    C_s = log_2(N_("page")(R))
  $,
)

Sebbene in un normale algoritmo di ricerca questo costo sia accettabile se non addirittura buono, in un contesto come il nostro dobbiamo fare di meglio. Infatti nel caso in cui avessimo 400k pagine, il costo medio sarebbe di circa 19 accessi a pagina. Questo costo è ancora troppo elevato per essere accettabile in un DBMS.

===== Ricerca Interpolata
Un miglioramento rispetto alla ricerca binaria può essere ottenuto tramite l'utilizzo della *ricerca interpolata*. L'idea è quella di scegliere il *pivot* in maniera più intelligente, andando a stimare la posizione del valore cercato all'interno del valore di ricerca.

L'idea di base è che le chiavi siano distribuite in maniera all'incirca *uniforme* nell'intervallo di ricerca. In questo modo possiamo stimare la _probabilità che una chiave sia minore di un certo $k$_ tramite la seguente formula:

#math.equation(
  block: true,
  numbering: none,
  $
    p_k = (k - k_("min")) / (k_("max") - k_("min"))
  $,
)

Dato il valore di $p_k$ possiamo stimare la posizione della pagina pivot tramite la seguente formula:

#math.equation(
  block: true,
  numbering: none,
  $
    P_i = ceil(P_1 + p_k dot (P_(N_("page")(R)) - P_1))
  $,
)

In sostanza $p_k$, supponendo che le chiavi siano distribuite uniformemente, ci consente di scalare il valore di $k$ all'interno dell'intervallo di ricerca. Utilizzando questa tecnica i costi saranno i seguenti:

- $C_s = O(log_2 log_2 N_("page")(R))$ nel caso 'medio'
- $C_s = O(N_("page")(R))$ nel caso peggiore, tuttavia questo caso è molto raro

Utilizzando ricerca interpolata nel caso di 400k pagine avremo un costo medio di circa 4 accessi a pagina, che è decisamente migliore rispetto alla ricerca binaria.

===== Altri costi per la ricerca interpolata
Ipotizzando di andare ad utilizzare la ricerca interpolata, andiamo a vedere quali sono gli altri costi associati alle altre operazioni sui file:

- Nel caso di *ricerca* di un *intervallo* ($k_1 <= k <= k_2$), ipotizzando di avere chiave uniformemente distribuite nell'intervallo $[k_("min"), k_("max")]$ avremo quanto segue:

  #math.equation(
    block: true,
    numbering: none,
    $
      f_s = (k_2 - k_1) / (k_("max") - k_("min") )
    $,
  )
  che corrisponde alla frazione totale delle pagine coperte dall'intervallo di ricerca rispetto al totale, questo elemento prende il nome di *fattore di selettività*. Dato questo fattore di selettività, il costo totale si può esprimere come:
  #math.equation(
    block: true,
    numbering: none,

    $
      coleq(#orange, ceil(log_2 N_("page")(R))) + coleq(#blue, ceil(f_s dot N_("page")(R))) - coleq(#green, 1)
    $,
  )
  dove il primo membro della somma corrisponde al #text(fill: orange)[costo per la ricerca della prima pagina] dell'intervallo, mentre il secondo membro corrisponde al #text(fill: blue)[costo per la lettura di tutte le pagine successive] nell'intervallo. Chiaramente andiamo a sottrarre 1 in quanto la #text(fill: green)[prima pagina è già stata letta].

- Nel caso di *inserimento*, dobbiamo innanzitutto individuare la pagina corretta in cui inserire il nuovo record. Questo comporta la scansione di tutte le pagine precedenti rispetto a quella di destinazione. Nel caso peggiore, quando tutte le pagine sono completamente occupate, è necessario spostare i record verso le pagine successive. Tuttavia, siccome il costo che ci interessa misurare è quello in termini di *accessi a pagina*, è sufficiente considerare lo spostamento di *un solo record per pagina* verso la pagina successiva, per ciascuna delle pagine che seguono quella di inserimento. Il costo totale dell’operazione di inserimento è quindi dato da:
  #math.equation(
    block: true,
    numbering: none,
    $
      C_i =
      coleq(#orange, C_s)
      +
      coleq(#blue, N_("page")(R))
      +
      coleq(#green, 1)
    $,
  )
  dove, il primo termine rappresenta il costo per la #text(fill: orange)[ricerca della pagina di inserimento], il secondo termine rappresenta il costo per la #text(fill: blue)[scansione delle pagine successive per lo spostamento dei record], e l'ultimo termine rappresenta il costo per la #text(fill: green)[scrittura del nuovo record nella pagina di destinazione].

- Nel caso di *cancellazione*, andiamo a considerare soltanto il caso di cancellazione *logica*, possiamo dire che questo ha costo come nel caso seriale: $C_d = C_s + 1$.

==== Confronto tra Modello Seriale e Sequenziale
Di seguito andiamo a presentare una tabella riassuntiva che confronta i due modelli di organizzazione per file appena presentati in termini dei costi a loro associati.

#figure(
  image("../images/ch07/05_sequential_serial_compare.png", width: 80%),
  caption: "Confronto tra modello seriale e sequenziale",
)

In generale non abbiamo un vincitore assoluto tra i due approcci, ognuno ha i suoi pro e contro:

- il modello *seriale* è ideale nel caso in cui abbiamo bisogno di effettuare tanti *inserimenti*, ma è pessimo nel caso in cui dobbiamo effettuare ricerche molto piccole
- il modello *sequenziale* è ideale nel caso in cui abbiamo bisogno di effettuare tante *ricerche*, ma è pessimo nel caso in cui dobbiamo effettuare tanti inserimenti

== Problemi di Ordinamento
Come già noto, l'ordinamento di dati è uno dei problemi più classici ed importanti nell'ambito dell'informatica. Anche nelle basi di dati si tratta di un'operazione molto comune: spesso infatti capita che sia necessario ordinare i dati in base a certi attributi per poter rispondere a query specifiche.

Altri casi molto comuni in cui è necessario ordinare i dati sono i seguenti:

- unione di dati provenienti da più tabelle
- eliminazione di duplicati
- raggruppamenti rispetto a determinate chiavi
- operazioni insiemistiche (unioni, intersezioni, differenze)


Seppur siano già state viste numerose tecniche di ordinamento in corsi precedenti, all'interno di un DBMS l'algoritmo di ordinamento maggiormente utilizzato  utilizzato è *external merge-sort*. Questo algoritmo funziona in due fasi:

- *ordinamento*: crea piccoli ordinamenti detti *run*
- *merge*: fonde più run ordinati in un unico file ordinato

Di seguito andiamo a vedere cosa succede ad ogni passo dell'algoritmo.

==== Fase di ordinamento
All'interno del *buffer* vengono ordinate $B$ (dimensione del buffer) pagine per volta tramite un algoritmo di *sort interno* e scrive il risultato su disco come un *run* ordinato. Questo processo viene ripetuto fino a quando tutte le pagine del file sono state lette e scritte su disco come run ordinate. Al termine del sorting otteniamo $n$ run dove:

#math.equation(
  block: true,
  numbering: none,
  $
    n = ceil((N_("page")(R)) / B)
  $,
)

==== Fase di merge
In questa avviene l'ordinamento vero e proprio. Sappiamo che abbiamo un buffer di $B$ pagine a disposizione, che è uno spazio limitato rispetto a quello effettivamente necessario. Per superare questo limite andremo a considerare $Z = B-1$ run. Per ognuna di queste run andremo a tenere all'interno del buffer una pagina, riservando l'ultima pagina per scrivere il risultato.

In questo modo, ad ogni passo andremo a scegliere il record più piccolo tra quelli nelle $Z$ pagine, scrivendolo nella pagina di output. Man mano che la pagina di output si riempie questa viene scritta su disco e andrà a dar forma al nuovo file ordinato, nel frattempo le $Z$ pagine vengono riempite progressivamente.

Questo processo verrà ripetuto per $Z / n$ fasi di merge, tutti i risultati prodotti saranno *intermedi* e verranno fusi nuovamente fino a quando non rimarrà un unico file ordinato.

#figure(
  image("../images/ch07/06_zmergesort.png", width: 80%),
  caption: "Rappresentazione schematica dell'algoritmo di external merge-sort con dimensione del buffer di 3 pagine, e pagine di dimensione 2",
)<fig:0706_zmergesort>

@fig:0706_zmergesort mostra schematicamente il funzionamento di external merge sort. Si noti come dal momento che il buffer può contenere 3 pagine di dimensione 2, allora $Z=2$. Non a caso il risultato della fase di sort consiste in 4 run ordinate di 3 pagine ciascuna.

==== Costo di External Merge-Sort
Andiamo ora a vedere quali sono i costi associati all'algoritmo di external merge-sort. In generale questo costo è estremamente dipendente dal numero di volte che i dati vengono spostati tra il buffer e la memoria permanente.

Per quanto riguarda l'algortmo in sé, sappiamo che questo può essere visto come diviso in un singolo passo di ordinamento e un certo numero $k$ di passi di merge. Indipendentemente dal tipo di operazione effettuata, ogni passo comporta la lettura e la scrittura di tutte le pagine del file. Definiamo quindi il costo di singolo passo $C_("step") = 2 dot N_("page")(R)$.

Il costo totale dell'algoritmo sarà dunque dato da:

#math.equation(
  block: true,
  numbering: none,
  $C_("tot") = (1 + k) dot C_("step") = (1 + k) dot 2 dot N_("page")(R)$,
)

A questo punto non resta che andare a investigare il numero di passi di merge $k$. Sappiamo che il numero di run iniziali $S$ è strettamente legato alla dimensione del buffer $B$: $S = ceil(N_("page")(R) / B)$. In ogni passo di merge, possiamo fondere $Z = B-1$ run, riducendo dunque il numero di run di un fattore  $Z$: $k = ceil(log_("Z") S) = ceil(log_("B-1") ceil(N_("page")(R) / B))$. Possiamo dunque riscrivere il costo totale come:

#math.equation(
  block: true,
  numbering: "(1)",
  $
    2 dot N_("page")(R) dot (1 + ceil(log_Z S))
  $,
)<eq:cost_zmergesort>

Nello specifico, nel caso in cui avessimo $N_("page")(R) < B^2$ allora avremmo bisogno di una sola fusione; questo dal momento che $S = N_("page")(R) / B < B$. In questo caso il costo totale si ridurrebbe a $C_("tot") = 4 dot N_("page")(R)$.

Di seguito vediamo alcuni benchmark che mostrano il costo di external merge-sort in funzione del numero di pagine avendo fissati $B=3$, $Z=2$ e la differenza rispetto ad avere $B=257$ e conseguentemente un valore di $Z=256$.

#figure(
  image("../images/ch07/07_zmergecosts1.png", width: 100%),
  caption: "Benchmark di external merge-sort in funzione del numero di pagine per due diverse dimensioni del buffer: a sinistra B=3, a destra B=257",
)<fig:0707_zmergesort_benchmark>
