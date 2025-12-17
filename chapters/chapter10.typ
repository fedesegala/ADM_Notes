#import "@preview/theorion:0.4.1": *
#import cosmos.fancy: *
#show: show-theorion
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#show: codly-init.with()
#import "../lib.typ": *
#import "chapter1.typ": *
#import "chapter2.typ": *
#import "chapter3.typ": *
#import "chapter4.typ": *
#import "chapter5.typ": *
#import "chapter6.typ": *
#import "chapter7.typ": *
#import "chapter8.typ": *
#import "chapter9.typ": *

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

= Metodi di accesso e Operatori Fisici
Riprendiamo in considerazione il nostro classico schema che rappresenta un database management system (DBMS) già presentato in @fig:rdbms_internal.

#align(center)[
  #image("../images/ch03/rdbms_internal.png", width: 80%)
]

Negli scorsi capitoli abbiamo visto le tre componenti che si pongono alla base dello *storage engine*, ossia il gestore della memoria secondaria, il gestore del buffer e il gestore delle strutture di memorizzazione. In questo capitolo ci concentriamo sui *metodi di accesso* ai dati, ossia l'interfaccia che lo storage engine offre al livello superiore del DBMS che si occupa della gestione *logica* dei dati e in quale modo gli strumenti logici che vengono utilizzati per manipolare i dati (ad esempio il linguaggio SQL) vengono tradotti in operazioni fisiche sullo storage.

== Gestione dei Metodi di Accesso
Per meglio comprendere l'interfaccia che lo storage engine offre, andiamo a considerare il sistema relazionale JRS che memorizza le relazioni tramite *heap files* e utilizza *indici* basati su _B+ Tree_. Gli operatori esposti dallo storage engine sono procedurali e possono essere raggruppati nelle categorie che elenchiamo di seguito:

- operatori per la creazione e gestione della *base* di *dati*
- operatori per la creazione e gestione di *heap* *file* e *indici*
- operatori per la gestione delle *transazioni*

=== Gestione della Base di Dati
Di seguito andiamo a illustrare i vari operatori disponibili per la gestione della base di dati.

===== Creazione di un DB
Per la creazione di un database abbiamo a disposizione un operatore che dato un path, un nome e un identificativo di transazione con la quale creare la base di dati, si occupa di creare la struttura necessaria a contenere l'intera base di dati. La funzione preposta alla creazione è `createDB: path x DbName x TransactionId -> null`.

===== Creazione di un Heap File
Una volta creato il database, è possibile creare al suo interno gli *heap file* che andranno a contenere le relazioni della base di dati. La funzione prende un input il nome della base di dati e uno specifico path: `createHeap: path + dbName x heapName + TransID -> null`.

===== Creazione di un Indice
Data una relazione, che viene memorizzata per mezzo di un heap file, possiamo andare a creare *indici* per garantire ricerca più efficiente su degli attributi di questa relazione. La funzione è definita come segue:

#align(center)[
  #block(width: 80%)[
    `createIndex: path x dbName x indexName x heapFile x attribute x ordering x unique x _transactionId -> null`
  ]]

dove unique serve a stabilire se l'indice sta venendo creato su una chiave, e l'ordering stabilisce se l'indice deve essere creato in ordine crescente o decrescente.

Tutti gli operatori di creazione appena visti hanno un corrispettivo per la cancellazione delle strutture: `dropDB`, `dropHeapFile` e `dropIndex`.

=== Operazioni sugli Heap File
Come già anticipato ogni relazione di una base di dati viene memorizzata per mezzo di *heap file*. Il DBMS deve esporre una serie di operatori per permettere inserimenti, cancellazioni, ricerche, aggiornamenti e altre operazioni di gestione sugli heap file. Di seguito vediamo le funzionalità principali che il sistema JRS mette a disposizione:

- $"HF_InsertRecord": "Record" -> "RID"$, permette di inserire un nuovo record all'interno di uno specifico heap file e restituisce il 'RID' (Record IDentifier) del record inserito
- $"HF_DeleteRecord": "RID" -> "null"$, permette di cancellare un record specificato dal suo 'RID'
- $"HF_GetRecord": "RID" -> "Record"$, permette di recuperare un record dato il suo 'RID'
- $"HF_UpdateRecord": "RID" x "FieldNum x NewField" -> "null"$, permette di aggiornare un campo specifico di un record individuato dal suo 'RID'

Potremmo avere bisogno di alcune operazioni per recuperare statistiche che riguardano il nostro heap file, come ad esempio il *numero di pagine* che esso utilizza e il *numero di record* memorizzati. Per questo motivo sono stati definiti gli operatori seguenti:

- $"HF_GetNpage": "null" -> "integer"$, restituisce il numero di pagine occupate
- $"HF_GetNrec": "null" -> "integer"$, restituisce il numero di record memorizzati

Il motivo per cui questi operatori sono necessari è che sono particolarmente utili per calcolare l'occupazione media di ogni pagina che ci consentirà di calcolare il valore atteso del costo di accesso ad un record.

=== Operazioni sugli Indici
Come sappiamo un indice consiste in un insieme di record di tipo *index entry*, organizzato (almeno in JRS) secondo una struttura B+ Tree. Un'index entry è costituita dagli attributi *value* e *RID*, dove il primo è la _chiave di ricerca_ all'interno dell'indice e il secondo il riferimento al record all'interno dell'heap file. Le operazioni ammesse sugli indici consentono di inserire e cancellare elementi, o di ottenere informazioni riguardo al B+ Tree stesso:

- $"Index_open": "Path x dbName x IndexName x TransId" -> "Index"$, apre un indice e restituisce un riferimento ad esso
- $"Index_close": "Index" -> "null"$, chiude un indice precedentemente aperto


- $"I_isKey": "Value" -> "boolean"$, consente di verificare se una specifica chiave è presente all'interno dell'indice
- $"I_InsertEntry": "Value" x "RID" -> "null"$, consente di inserire una nuova index entry all'interno dell'indice
- $"I_DeleteEntry": "Value" x "RID" -> "null"$, consente di cancellare una index entry dall'indice


- $"I_getNKey": "null" -> "integer"$, restituisce il numero di chiavi presenti nell'indice
- $"I_getNleaf": "null" -> "integer"$, restituisce il numero di foglie presenti nell'indice
- $"I_getMin": "null" -> "Value"$, restituisce il valore minimo presente nell'indice
- $"I_getMax": "null" -> "Value"$, restituisce il valore massimo presente nell'indice

=== Operatori dei Metodi di Accesso
Dopo aver osservato come è possibile interagire con i componenti di base di una base di dati, possiamo ora vedere come sia possibile utilizzarli in un contesto più ampio, ossia per rispondere a delle query.

Il gestore dei metodi di accesso fornisce gli operatori per trasferire dati tra la memoria permanente e la memoria principale in maniera tale da rispondere a delle query effettuate su una base di dati. Gli operatori che fornisce il gestore dei metodi di accesso sono utilizzati per implementare le gli operatori utilizzati a livello logico dai "query plan" che vengono generati dal *query optimizer*.

I record di un heap file o di un indice sono acceduti tramite operazioni di *scansione*. Per quanto riguarda un heap file scan, avremo un operatore che semplicemente legge un record dopo l'altro, mentre un index scan operator consiste di ottenere il RID di un record dato un valore chiave o un intervallo di valori.
A livello pratico questi operatori per la scansione sono implementati sotto forma di *iteratori*, anche detti *cursori*, ossia oggetti con funzionalità che permettono di ottenere i risultati un record per volta. Questi iteratgori vengono tipicamente creati per mezzo di una funzione _open_ e mettono a disposizione le seguenti funzionalità:

- _isDone_: per capire se esistono ancora record da leggere per un certo risultato
- _getCurrent_: per ottenere il record attualmente puntato dall'iteratore
- _next_: per spostare l'iteratore al record successivo
- _close_: per chiudere l'iteratore e liberare le risorse ad esso associate

Una volta che un cursore è stato creato e aperto, possiamo avviare una *scansione* utilizzando uno schema simile allo pseudocodice che mostriamo in seguito.

```java
while !cursor.isDone(){
  value = cursor.getCurrent();

  // operations with the value

  cursor.next();
}

```

==== Heap File Scan
Sappiamo che nel momento in cui vogliamo utilizzare uno scan operator abbiamo bisogno sempre di utilizzare la sua funzionalità di _apertura_. Per lavorare su un heap file abbiamo due alternative a disposizione:

- $"HFS_Open": "Heapfile" -> "ScanHeapFile"$, apre uno scan su un heap file partendo dal suo primo record
- $"HFS_Open": "Heapfile x RID" -> "ScanHeapFile"$, apre uno scan su un heap file partendo dal record specificato

Dopo aver inizializzato il cursore tramite apertura, possiamo utilizzare varie funzionalità:

- $"HFS_IsDone": "null" -> "boolean"$, verifica se la scansione ha raggiunto la fine
- $"HFS_next": "null" -> "null"$, sposta la scansione al record successivo
- $"HFS_getCurrent": "null" -> "RID"$, restituisce il record attualmente puntato dal cursore
- $"HFS_Reset": "null" -> "null"$, riporta il cursore al primo record dell'heap file
- $"HFS_Close": "null" -> "null"$, chiude lo scan e libera le risorse ad esso associate

==== Index Scan
Nel caso di uno scan su indice, come al solito abbiamo necessità di '_aprire_ lo scan operator' accedendo ad un iteratore. Per fare questo abbiamo a disposizione la seguente funzionalità:

- $"IS_Open": "Index x FirstValue x LastValue" -> "ScanIndex"$, apre uno scan su un indice per un intervallo di valori compreso tra FirstValue e LastValue.

Una volta aperto abbiamo a disposizione tutte le funzionalità già specificate anche per l'heap file scan, ossia $"IS_isDone"$, $"IS_next"$, $"IS_getCurrent"$, $"IS_Reset"$ e $"IS_Close"$.

=== Esecuzione delle Query
Dopo aver visto tutti gli operatori messi a disposizione dal gestore dei metodi di accesso, andiamo a vedere alcuni esempi di programmi che utilizzano i metodi di accesso forniti dallo storage engine per eseguire delle semplici query SQL.

Mostreremo in maniera sommaria come una query SQL viene tradotta in una *programma procedurale* che utilizza gli operatori di accesso per ottenere i risultati desiderati. Per semplicità possiamo assumere che questo programma sia generalo dal modulo *query optimizer*.

Supponiamo di voler considerare una relazione *`Student`* con gli attributi `Name`, `StudentNumber`, `Address` e `City`. Ipotizziamo di volere eseguire una query del tipo:

```SQL
SELECT Name, FROM Students WHERE City = 'Pisa';
```

Assumendo che la relazione `Students` sia memorizzata in un heap file con lo stesso nome, la struttura di un possibile programma per eseguire questa query potrebbe essere:

```java
Heapfile students = HF_Open(path, dbName, "students", transID);
ScanHeapFile iteratorHF = HFS_Open(students);

while (!iteratorHF.isDone()) {
  RID rid = iteratorHF.getCurrent();
  Record record = Students.HF_GetRecord(rid);
  if (record.getField(4).("Pisa")) {
    System.out.println(record.getField(1));
  }
  iteratorHF.HFS_next();
}

iteratorHF.Close();
students.Close();
```
Supponiamo ora di avere a disposizione un *indice* *`IdxCity`* sull'attributo `City` della relazione. Possiamo ottenere un programma più efficiente per ottenere lo stesso risultato utilizzando uno scan su indice:

```java
Heapfile students = HF_Open(path, dbName, "students", transID);
Index idxCity = I_open(path, dbName, "IdxCity", transID);

// apertura dello scan sull'indice per il valore 'Pisa'
ScanIndex iteratorIdx = IS_Open(idxCity, "Pisa", "Pisa");


while (!iteratorHF.isDone()) {
  RID rid = iteratorIdx.IS_getCurrent().getRid();
  Record record = Students.HF_GetRecord(rid);
  System.out.println(record.getField(1));
  iteratorIdx.IS_next();
}

iteratorIdx.IS_Close();
idxCity.I_Close()
students.HF_Close();
```
#pagebreak()

=== Da un Operatore Logico a un Piano di Accesso Fisico
In questa sezione andiamo mostrare ad alto livello come, data una query, questa possa essere interpretata secondo un *albero logico*. Tuttavia questa rappresentazione non è così comoda per essere eseguita direttamente su una macchina. Per questo motivo mostreremo tutte le trasformazioni che portano da un albero logico ad un *piano di accesso fisico* ai dati.

Supponiamo di dover svolgere la seguente query SQL:

```SQL
SELECT PkEmp, EName
FROM Employee JOIN Deparment
ON Employee.FKDept = Department.PkDept
WHERE Department.Location = 'Pisa' AND Employee.Salary > 2000;
```

Una prima traduzione della query in un albero logico si può vedere in @fig_query_logical_tree. Questa traduzione è piuttosto diretta e segue passo passo la struttura della query SQL, con il `join` tra le due relazioni che avvengono prima della selezione sui dati.

#figure(
  image("../images/ch10/logical_tree.png", width: 30%),
  caption: "Albero logico della query in Algebra Relazionale",
)<fig_query_logical_tree>

Volendo, possiamo applicare delle ottimizzazioni alla nostra query per fare in modo che il `join` avvenga dopo le selezioni che vengono applicate in maniera distinta su ognuna delle relazioni. In questo modo possiamo ridurre il numero di tuple che devono essere considerate durante il join stesso. Dopo aver ottenuto questa ottimizzazione è possibile andare ad ottenere un nuovo albero logico che sarà poi tradotto in un piano di accesso fisico utilizzando gli operatori messi a disposizione dallo storage engine.

#figure(
  image("../images/ch10/query_physical tree.png", width: 90%),
  caption: "Piano di accesso fisico della query dopo ottimizzazione",
)<fig_query_physical_tree>

== Operatori Fisici
Nel momento in cui ci troviamo a dover svolgere una query, il gestore dei *piani di accesso* si occupa di creare un piano di accesso ai dati per lo *storage engine*, richiedendo che il piano di accesso venga eseguito dal gestore dei metodi di accesso.

In sostanza è necessario mappare gli operatori logici che possiamo vedere come la nostra algebra relazionale in operatori fisici che utilizzino le funzionalità messe a disposizione dallo storage engine. Per semplificare la trattazione in questo capitolo assumeremo di utilizzare un DBMS relazionale in cui le relazioni sono memorizzate in *heap file* o in *B+ Tree* utilizzati come organizzazioni primarie. Un'ulteriore assunzione che faremo è che avremo a disposizione vari *indici*: unici, non unici, clusterizzati e non clusterizzati.

=== Physical Query Plan
Un piano di accesso fisico è costituito da un insieme di operatori fisici che vengono collegati tra loro in una struttura ad albero. Ogni operatore è in realtà un *iteratore* che:

- ritorna una collezione di oggetti (come fanno gli operatori algebrici)
- hanno un certo tipo
- possono permettere accesso ai record di una collezione secondo un ordine

Per ognuno degli operatori fisici considerati andremo a studiare il *costo* di esecuzione $C$ e la *cardinalità* del *risultati* $E_"rec"$. Come già anticipato, possiamo andare a comporre un piano di accesso ai dati combinando vari operatori, in maniera tale che l'output di ogni operatore sia l'input per l'operatore successivo.

Una volta che lo storage engine riceve un piano di accesso, questo viene eseguito seguendo la logica definita dagli operatori fisici che lo compongono e restituendo i risultati al livello superiore del DBMS. Come abbiamo già visto nella sezione precedente, ogni iteratore può essere visto come un oggetto descritto da uno stato e che espone varie funzioni:

- _open_: per inizializzare l'iteratore
- _isDone_: per verificare se ci sono ancora record da leggere
- _next_: per spostarsi al record successivo
- _reset_: per riportare l'iteratore al primo record
- _close_: per chiudere l'iteratore e liberare le risorse ad esso associate

Data una query rappresentata tramite un piano di accesso fisico, lo storage engine seguen il seguente schema per andare a eseguire il piano richiesto.

```java
plan.open();
while (!plan.isDone()) {
  System.out.println(plan.next());
}
plan.close();
```
#example-box("Svolgimento di un piano di esecuzione", [
  Si consideri per esempio il piano di esecuzione che viene mostrato nell'immagine seguente:

  #align(center)[
    #image("../images/ch10/access_plan.png", width: 60%)
  ]

  Di seguito mostriamo i vari passaggi svolti dallo storage engine per svolgerlo:

  + L'operatore alla radice del piano è un nodo di *proiezione* che richiede un record al suo operando (il nodo figlio), ossia un *nested loop*

  + Il nested loop, che serve ad implementare la funzionalità di join, richiede due operandi:

    - l'operando a sinistra è un'operazione di *filtering* che a sua volta richiede un record all'operatore *tableScan* fintanto che questo non restituisce un operatore che soddisfi la condizione specificata nel filtro

    - l'operando a destra è un'altra operazione di filtraggio, che richiede record all'operazione *tableScan* sulla tabella `Exams` fintanto che non viene trovato un record che soddisfi la condizione del filtro

  Possiamo notare il fatto che, utilizzando operatori di filtraggio a monte dell'operazione di join tra le due relazioni, riusciamo a ridurre significativamente il numero di record sui quali operare un confronto di uguaglianza tra gli attributi `StudentNumber` e `Candidate`.
])

=== Algebra Relazionale Estesa
Andiamo a definire all'interno di questa sezione un modello di algebra relazionale esteso che ci permetta di andare in seguito a definire gli operatori fisici che opereranno sui nostri dati. Il motivo per cui andiamo ad estendere l'algebra relazionale classica è che, quest'ultima suppone di lavorare con *insiemi*, che non ammettono elementi duplicati. Per questo motivo andremo ad _estendere_ la nostra algebra in maniera tale che possa lavorare su *multiset* o *bag* di dati, in maniera tale da poter replicare il modello SQL. Di seguito illustriamo gli operatori:

- *$pi_X^b (O)$ Proiezione con duplicati*:  dati un multiset di record $O$ e un insieme di attributi $X$ restituisce un multiset di record contenente solo gli attributi in $X$.

- *$delta(O)$ Eliminazione dei duplicati*: dato un multiset di record $O$ restituisce un insieme di record eliminando i duplicati.

- *$tau_X (O)$ Ordinamento dei duplicati*: dato un multiset $O$ e un insieme di attributi $X$ restituisce una lista di record ordinata secondo gli attributi in $X$. Corrisponde all'operatore SQL `ORDER BY`.

- *Unione, Intersezione e Differenza* di multiset di cui mostriamo in seguito il funzionamento in questo caso:

  - ${1,1,2,3} union^b {2,2,3,4} = {1,1,2,2,3,2,2,3,4}$

  - ${1,1,2,3} inter^b {2,2,3,4} = {2,3}$

  - ${1,1,2,3} -^b {1,2,3,4} = {1}$

Una volta definite le componenti principali del nostro modello di algebra relazionale possiamo andare a mostrare come questi operatori vengono implementati e i vari costi legati alla loro esecuzione. Ricordiamo sempre che il nostro modello di costo è dato dal numero di pagine accedute in memoria secondaria durante l'esecuzione di un operatore. Nel caso in cui utilizziamo un indice, avremo anche un costo legato al numero di accessi alle pagine dell'indice stesso.

=== Operatori Fisici per le relazioni
È possibile leggere i record di una relazione tramite diverse funzionalità, ognuna di questa si può vedere come una funziona che ha come unico argomento il nome della relazione $R$ da leggere. Questi nodi sono tipicamente le *foglie* di un piano di esecuzione.

In generale la cardinalità del risultato è un valore che non dipende da altro se non dalla numero di record della relazione stessa, ossia $E_"rec" (R) = N_"rec" (R)$.
===== Table Scan
L'operatore *_TableScan(R)_* ritorna tutti i record della relazione $R$ nell'ordine in cui questi sono memorizzati all'interno dell'heap file. Il costo di questa operazione è dato dal numero di pagine occupate dalla relazione $R$:

#math.equation(
  block: true,
  numbering: none,
  $
    C_"TableScan(R)" = N_"pag" (R)
  $,
)

===== SortScan
L'operatore *_SortScan(R, ${A_i}$)_* ritorna tutti i record della relazione $R$ secondo un ordine crescente stabilito sui valori dell'attributo $A_i$. L'ordinamento avviene tramite l'algoritmo di *external merge sort* già descritto in precedenza. In generale il costo di questo operatore dipende dal numero di pagine occupate dalla relazione, dal numero di pagine $B$ nel buffer e dall'implementazione scelta per il merge sort.

Per quanto riguarda il costo di esecuzione, possiamo ipotizzare che $N_"page" (R) < B^2$ e possiamo ricordare che il costo di external merge sort è di $4 dot N_"page" (R)$, è però vero che la versione originale di external merge sort richiede di scrivere su disco il risultato dei merge incrementali, ciò non è richiesto qui dal momento che abbiamo a che fare con *iteratori*, dunque possiamo evitare di contare le scritture su file ordinato, la formula in @eq:cost_zmergesort diventa dunque

#math.equation(
  block: true,
  numbering: none,
  $
    2 dot N_("page")(R) dot (ceil(log_Z S)) space ==> space C_"SortScan"(R, A_i) = 3 dot N_"page" (R)
  $,
)

===== Index Scan
L'operatore *_IndexScan(A, Idx )_* ritorna i record della relazione $R$ che sono memorizzati nell'indice Idx ordinati secondo l'ordine stabilito sull'attributo $A_i$. Il costo è legato al tipo di indice e al tipo di attributo su cui questo è definito. Lo vediamo in dettaglio di seguito:

#math.equation(
  block: true,
  numbering: none,
  $
    C = cases(
      N_"leaf" ("Idx") + N_"pag" (R) space "if Idx is clustered",
      N_"leaf"("idx") + N_"rec" (R) quad space space"if Idx is on a key, otherwise: ",
      N_"leaf"("Idx") + ceil(N_"key" ("Idx") dot Phi(ceil((N_"rec" (R)) / (N_"key" ("Idx"))), N_"pag" (R)))
    )
  $,
)

Applicando questo operatore, la prima eventualità è quella migliore, in cui l'indice riflette l'ordinamento della memoria. Nel secondo caso, invece l'indice non è più clusterizzato e non possiamo assumere che dopo aver acceduto ad una pagina per un RID, dovremo accedere ad un'altra pagina per il RID successivo. Il terzo caso è invece quello peggiore, l'unica cosa che possiamo fare è stabilire un limite superiore tramite la formula di Cardenas.

==== Index Sequential Scan
L'operatore *_IndexSequentialScan(A, Idx )_* ritorna tutti i record della relazione $R$ che sono memorizzati con l'organizzazione primaria basata su B+ Tree ordinati in base all'attributi chiave della relazione. Il costo in questo caso è dato semplicemente da:

#math.equation(
  block: true,
  numbering: none,
  $
    C_"IndexSequentialScan(A, Idx)" = N_"leaf"("Idx")
  $,
)

Notiamo che questa tecnica si differenzia rispetto alla precedente proprio per il fatto che usiamo un B+ Tree come organizzazione primaria della nostra relazione, le foglie del B+ Tree contengono esattamente i dati della relazione, mentre nel caso di un indice secondario è poi necessario andare a recuperare i record dall'heap file partendo dal RID memorizzato nell'indice.

=== Operatori di Proiezione e Deduplicazione
Andiamo ora ad analizzare i vari operatori fisici che ci permettono di effettuare operazioni di proiezione e deduplicazione sui record delle nostre relazioni.

===== Proiezione
L'operatore *_Project(O, ${A_i}$)_* prende in input un multiset di record $O$ e un insieme di attributi ${A_i}$ e restituisce un multiset di record contenente solo gli attributi in ${A_i}$. Il numero di record in output da questo operatore è lo stesso del numero di record in input, e analogamente, il costo in termini di numero di accessi a pagina è dato dal costo dell'origine $O$.

#math.equation(
  block: true,
  numbering: none,
  $
    C = C(O) quad quad quad quad E_"rec" = E_"rec" (O)
  $,
)

===== Index Only Scan
L'operatore *_IndexOnlyScan(R, Idx, ${A_i}$)_* è in realtà un operatore per la scansione di una relazione, tuttavia ci consente di effettuare una *proiezione* in maniera intrinseca andando a ritornare record soltanto composti dagli attributi sui quali è costruito l'indice. Il costo di questo operatore è dato dal numero di foglie dell'indice.

===== Deduplicazione
L'operatore *_Distinct(O)_* prende in input un multiset di record $O$ e restituisce un insieme di record eliminando i duplicati. Il costo è lo stesso del costo dell'origine $O$.

Chiaramente questo costo è così basso solamente nel caso in cui i dati iniziali siano già ordinati, in caso contrario sarà necessario effettuare un'operazione di ordinamento preliminare sui dati, il cui costo è quello di external merge sort.

===== Utilizzo di Hashing
Un'alternativa all'utilizzo dell'ordinamento per effettuare deduplicazione dei record è quello di utilizzare *hashing*. L'idea è quella che, utilizzando una qualsiasi funzione di hash, tutti i record duplicati avranno lo stesso hash code.

Possiamo dunque utilizzare questa funzione di hashing per dividere i record in *bucket* della dimensione della memoria o del buffer, in maniera da poter caricare in maniera atomica ogni bucket, procedendo poi ad eliminare i duplicati all'interno dei bucket già presenti in memoria.


Il costo di questo operatore sarà dunque dato da:
#math.equation(
  block: true,
  numbering: none,
  $
    C = C(O) + 2 dot N_"page"(O)
  $,
)

Il motivo per cui moltiplichiamo il numero di pagine di $O$ per due è che, una volta avremo bisogno di accedere alle pagine per creare i bucket, la seconda volta per caricare questi in memoria in modo tale da fare deduplicazione.

=== Operatori di Selezione
In questa sezione andiamo a mostrare alcune possibilità per effettuare operazioni di selezione sui record delle nostre relazioni.

====== Filter
La prima opzione è quella di applicare un banale operatore di *filtering*: *_Filter(O, $psi$)_* che effettua selezione senza indici dei record provenienti dalla sorgente $O$. Il costo in questo caso è lo stesso della sorgente: $C = C(O)$.

Il grande vantaggio di questo strumento è che può essere sempre applicato, per qualsiasi condizione e su qualsiasi tipo di dato. Lo svantaggio principale è che non da alcun vantaggio nel caso in cui abbiamo a disposizione strutture dati ausiliarie.

===== Index Filter
Vediamo ora come sia possibile migliorare sfruttare la presenza di un indice per la gestione delle selezione. Questa operazione consiste nel trovare i record di $R$ che soddisfano la condizione $psi$ utilizzando un indice $I$ che sia definito sugli attributi coinvolti in $psi$.

L'operatore *_IndexFilter(R, I, $psi$)_* opera in due fasi: utilizza l'indice per trovare l'insieme ordinato dei RID che soddisfano $psi$ e poi li utilizza per accedere a questi record. L'operatore ha un costo che è dato dalla somma del costo di accesso all'indice e del costo di accesso ai record stessi: $C = C_I + C_D$.

===== Index Sequential Filter
L'operatore *_IndexSequentialFilter(R, I, $psi$)_* ritorna i record di $R$ che soddisfano $psi$ in maniera ordinata. In questo caso la condizione deve essere riferita unicamente ad attributi che sono parte della chiave di costruzione dell'indice. L'operatore ha costo $C = ceil(s_f (psi) dot N_"rec" (R))$

È anche possibile utilizzare una variante di questo operatore per effettuare anche una *proiezione*, ossia *_IndexOnlyFilter(R, I, ${A}, psi$)_* che ritorna i record di $R$ proiettati sugli attributi ${A}$ che soddisfano $psi$. Anche in questo caso il costo è dato da $C = ceil(s_f (psi) dot N_"rec" (R))$.

===== Filtri con Predicati Complessi
Spesso può capitare di dovere svolgere operazioni di selezione che coinvolgono più attributi. In questi casi, avremo bisogno di utilizzare più indici, uno per ogni attributo coinvolto nella selezione. Possiamo vedere questa selezione come divisa in due parti. La prima parte è quella della ricerca su indice, che sia nel caso in cui le condizioni sono in _and_ o in _or_ ha costo:

#math.equation(
  block: true,
  numbering: none,
  $
    C_I = ceil(sum_(k=1)^n C_I^k)
  $,
)

dove $k$ varia tra i $n$ indici utilizzati per la selezione. La seconda parte è quella dell'accesso ai dati, che dipende dal tipo di condizione, possiamo in ogni caso stimare il numero di record selezionati dalla condizione $psi$ tramite $E_"rec" = ceil(s_f (psi) dot N_"rec" (R))$ e a questo punto utilizzare la formula di Cardenas per stimare il costo di accesso ai dati:

#math.equation(
  block: true,
  numbering: none,
  $
    C_D = ceil(psi(E_"rec") dot N_"pag" (R))
  $,
)

==== Esempio di Piano di Accesso con Filtraggio
Supponiamo di avere la seguente query SQL:

```SQL
SELECT * A
FROM R
WHERE A BETWEEN 50 AND 100;
```
Possiamo vedere questa query risolta tramite l'albero logico che viene trasformato in un piano di accesso fisico come mostrato nell'immagine che segue:

#align(center)[
  #image("../images/ch10/ex1.png", width: 60%)
]

In questo caso, il costo dell'intero accesso ai dati sarà dato semplicemente dal numero di pagine necessarie per effettuare la tableScan. Gli operatori successivi, essendo iteratori, non fanno altro che analizzare uno ad uno i record già forniti dall'operazione di scansione.

Supponiamo però di avere a disposizione un indice definito sull'attributo `A` e di modificare leggermente la nostra query per fare in modo da non dover proiettare sul solo attributo `A`. In questo caso il possiamo sfruttare l'operatore *IndexFilter* per ottenere un piano di accesso fisico più efficiente.

=== Operatori Fisici per il Raggruppamento
Andiamo ora a mostrare come è possibile tradurre operazioni di raggruppamento in operatori fisici che possano essere eseguiti dallo storage engine. In algebra relazionale questo operatore viene denotato tramite ${A_i} space gamma space {f_i}$.


===== Operatore GroupBy
L'operatore *_GroupBy(O, ${A_i}$, ${f_i}$)_* viene utilizzato per ordinare i record dell'origine $O$ secondo gli attributi ${A_i}$ utilizzando le *funzioni di aggregazione* ${f_i}$. Più specificamente, queste funzioni di aggregazione servono ad implementare implementare le funzionalità di aggregazione che è possibile utilizzare in SQL come `SUM`, `COUNT`, ... oppure a replicare il comportamento della clausola `HAVING`.

Similmente a quanto accade per l'operatore di deduplicazione, anche in questo caso è necessario che i dati provenienti dalla sorgente $O$ siano *ordinati* sulla base dell'attributo o degli attributi ${A_i}$. Il costo di questa operazione è dunque dato dal costo della sorgente $C = C(O)$.

===== Hashing per il Raggruppamento
In alternativa a supporre che i dati siano ordinati, è possibile, come nel caso della deduplicazione, utilizzare tecniche basate su *hashing*. In questo caso abbiamo a disposizione l'operatore *_HashGroupBy(O, ${A_i}$, ${f_i}$)_*. Il funzionamento di questo operatore è il seguente:

- per ogni riga di input viene calcolato un hash code basato sugli attributi ${A_i}$ in modo da partizionare i record nei rispettivi gruppi. A questo punto vengono utilizzate le funzioni ${f_i}$ per ottenere i valori aggregati per ogni gruppo.

Chiaramente è ancora possibile avere delle collisioni e che gruppi diversi finiscano nello stesso bucket, ma dobbiamo sempre ricordare il fatto che, una volta che un bucket è caricato in memoria, possiamo trascurare i costi computazionali. Il costo di questa operazione è dunque dato da: $C = C(0) + 2 dot N_"pag" (O)$.


==== Esempio di Piano di Accesso con Raggruppamento
Andiamo di seguito a vedere come un piano di albero relazionale rappresentate una query che prevede di usare raggruppamenti possa essere trasformato in piano di accesso fisico. Supponiamo di dover lavorare con la seguente query:

```SQL
SELECT A, SUM(B)
FROM R
WHERE A BETWEEN 50 AND 100
GROUP BY A
HAVING COUNT(*) > 1;
```
La seguente query può essere trasformata in albero logico e successivamente in piano di accesso fisico come mostrato nell'immagine che segue:

#align(center)[
  #grid(
    columns: (40%, 20%),
    column-gutter: 8%,
    align: horizon,
    image("../images/ch10/groupby_logic.png"), image("../images/ch10/groupby_physic.png"),
  )
]

=== Operatori Fisici per il JOIN
Dopo aver visto tutti gli operatori fisici che è possibile applicare ad una singola relazione, andiamo ora a vedere come sia possibile implementare dal punto di vista fisico le operazioni di *join* tra due relazioni.

In questa trattazione andremo a considerare unicamente il caso di *equi-join* tra due origini $O_E$ ed $O_I$ ossia origine esterna e origine interna. Andremo a denotare il tutto nella maniera seguente: $(O_E limits(join)_(psi_J) O_I)$ dove $psi_J$ è la *condizione di join*.

===== Nested Loop JOIN
La prima e molto comune tecnica che mostriamo per andare ad effettuare un join tra due sorgenti è quella di utilizzare un *nested loop join*. Si tratta di un'implementazione molto semplice che segue la seguente logica:

```java
for (Record r: R)      // scorriamo la sorgente esterna
  for (Record s: S)    // per ogni record esterno, scorriamo gli interni
    if joinCondition(r, s)   // controlliamo la condizione di join
      output.add((r,s));
```
Il costo di questo algoritmo è dato dal costo di accesso alla sorgente esterna, più il costo di accesso alla sorgente interna moltiplicato per il numero atteso di record nella sorgente esterna:

#math.equation(
  block: true,
  numbering: none,
  $
    C_"NestedLoop" = C(O_E) + E_"rec" (O_E) dot C(O_I)
  $,
)

#remark[
  È di fondamentale importanza notare che in questo caso l'ordine delle sorgenti è cruciale. Il costo del primo operando della somma è sostanzialmente trascurabile, ciò che è di grande impatto è il prodotto.

  In generale sarà di fondamentale importanza scegliere come sorgente esterna quella che ha un numero significativamente minore di record. Nel caso in cui non si abbia grande differenza in termini di numero di record, sarà preferibile scegliere quella che occupa il numero minore di pagine.
]

Una proprietà molto interessante di questo algoritmo è che gli elementi di $O_E$ vengono letti secondo l'ordine con cui sono memorizzati nell'heap file. Se dunque la sorgente esterna è 'più  importante' di quella interna, otterremo una sorta di *ordinamento lessicografico*.

===== Page Nested Loop JOIN
Nel caso precedente abbiamo un importante punto di inefficienza: la sorgente interna viene letta completamente ogni qual volta viene letto un record della sorgente esterna.
Una soluzione a questo è utilizzare la scansione della sorgente interna soltanto una volta per ogni *pagina* della sorgente esterna.

```java
for (Page p_r: R)     // scorriamo R per pagine
  for (Page p_s : S)  // per ogni pagina interna scorriamo S
    for (Record r : p_r)    // per ogni record nella pagina esterna
      for (Record s : p_s)  // per ogni record nella pagina interna
        if joinCondition(r, s)
          output.add((r,s));
```

Il costo di questo algoritmo sarà ora dato dalla seguente equazione:

#math.equation(
  block: true,
  numbering: none,
  $
    C_"PageNestedLoop" & = C(O_E) + N_"pag"(O_E) dot C(O_I) \
                       & = N_"pag" (O_E) + N_"pag" (O_E) dot N_"pag" (O_I)
  $,
)

Vediamo come in questo caso il costo sarà dominato dal prodotto tra il numero di pagine delle due sorgenti, mentre prima era dominato dal prodotto tra il numero di record di una sorgente e il numero di pagine dell'altra, il che rappresenta un miglioramento significativo.

Per quanto sembri che dal punto di vista del numero di operazioni effettuate questo algoritmo sia quasi peggiore del precedente, in realtà il due cicli `for` interni non avranno particolare influenza, dal momento che siamo interessati solamente al numero di accessi a pagina.

Ulteriori miglioramenti a questo algoritmo possono essere ottenuti caricando in memoria *più pagine* dallo storage secondario. Questo permetterà di ridurre ulteriormente il numero di scansioni della sorgente interna. Se assumiamo di poter caricare tutta la sorgente esterna in memoria, il costo di questo algoritmo diventa:

#math.equation(
  block: true,
  numbering: none,
  $
    C_"PageNestedLoop" = N_"pag" (O_E) + N_"pag" (O_I)
  $,
)

Dal momento che la sorgente esterna è tutta in memoria, non avremo più bisogno di effettuare scansioni multiple della sorgente interna. Per quanto questo algoritmo sia molto più efficiente, ci sono casi in cui vorremmo che il join restituisca risultati ordinati in maniera 'lessicografica', in questo caso questo algoritmo non può essere applicato.

===== Index Nested Loop JOIN
Un'ulteriore ottimizzazione che possiamo applicare al nested loop join è quella di sfruttare un indice per risolvere le *condizioni di uguaglianza* presenti nella condizioni di join. In questo caso l'algoritmo diventa:

```java
for (Record r : O_E)
  for (Record s : IndexFilter(O_I, Idx, r.A_j = s.A_j))
    output.add((r,s));
```
La chiave di questo algoritmo è utilizzare l'operatore *Index Filter* utilizzando il valore della chiave del record esterno per cercare i record corrispondenti nella sorgente interna in maniera efficiente. Il costo di questo algoritmo sarà dato da:

#math.equation(
  block: true,
  numbering: none,
  $
    C_"IndexNestedLoop" = C(O_E) + E_"rec" (O_E) dot (C_I + C_D)
  $,
)

====== Merge JOIN
Un'altra tecnica comune per effettuare il join tra due sorgente è quella di utilizzare un *merge join*. Se le due sorgenti sono _ordinate_ secondo gli attributi coinvolti nella condizione di join, possiamo utilizzare questo algoritmo:

```java
Record r = O_E.first(); // null if empty
Record s = O_I.first(); // null if empty

while (r IS NOT NULL and S IS NOT NULL) {
  if r[A_i] = s[A_j] {  // controllo della condizione di join
    output.add((r,s));
    s = O_I.next(); // i valori s soddisfano la condizione di join
  } else {
    r = O_E.next(); // spostiamo il cursore della relazione esterna
  }
}
```

Il costo di questo algoritmo è semplicemente dato dalla somma degli accessi alle due sorgenti:

#math.equation(
  block: true,
  numbering: none,
  $
    C_"MergeJoin" = C(O_E) + C(O_I)
  $,
)

Ovviamente, per quanto sia un algoritmo molto efficiente, la condizione sull'ordinamento delle due sorgenti lo rende applicabili soltanto in casi particolari.

====== Hash JOIN
Senza dubbio l'algoritmo di merge join è uno dei più efficienti, tuttavia richiede una precondizione relativamente stringente. Per questo motivo viene in nostro aiuto l'algoritmo di *hash join* che come nei casi precedenti sfrutta tecniche di hashing per sorvolare il requisito di ordinamento dei dati. Questo algoritmo funziona in due fasi: *partizionamento* e *probing*.

La differenza rispetto agli algoritmi precedenti consiste nel fatto che in questo caso abbiamo a che fare con due relazioni, non più con una relazione soltanto.

Nella fase di _partizionamento_ i record delle due sorgenti vengono divisi in *bucket* tramite una funzione di hashing basata sugli attributi coinvolti nella condizione di join. In questo modo i record che possono soddisfare la condizione di join finiranno tutti nello stesso bucket.

Nella fase di _probing_  per ogni partizione $B_i$ i record di $O_E$ vengono letti e inseriti in una hash table con $B$ pagine di memoria utilizzando la funzione di hashing $h_2$. La stessa funzione (basata sugli attributi di join) viene utilizzata una volta letti i record di $O_I$ per cerchiamo i record corrispondenti nella hash table tramite $h_2$. Una volta trovati i record, controlleremo la condizione di join e in caso positivo li aggiungeremo all'output. Notiamo che questa operazione può essere effettuata in memoria, dunque non ha un costo computazionale significativo. Vediamo questa procedura illustrata in @fig_10_probing.

#figure(
  image("../images/ch10/probing_partitions.png", width: 70%),
  caption: "Fase di probing delle partizioni nell'hash join",
)<fig_10_probing>

Dal momento che entrambe le sorgenti vengono lette completamente sia per il probing che per il partizionamento, il costo di questo algoritmo è dato da:

#math.equation(
  block: true,
  numbering: none,
  $
    C_"HashJoin" = C(O_E) + C(O_I) + 2 dot (N_"pag" (O_E) + N_"pag" (O_I))
  $,
)

===== Cardinalità di un JOIN
Così come per le operazioni di filtraggio è interessante andare ad analizzare la cardinalità del risultato di un join tra due relazioni. Data infatti la seguente operazione di join:

#math.equation(
  block: true,
  numbering: none,
  $
    R limits(join)_(psi_J) S = sigma_(psi_J) (R times S)
  $,
)

Possiamo andare a studiarne la cardinalità tramite la seguente formula:

#math.equation(
  block: true,
  numbering: none,
  $
    E_"rec" = ceil(s_f(psi_J) dot E_"rec" (O_E) dot E_"rec" (O_I))
  $,
)

In questo caso il fattore di selettività $s_f(psi_J)$ rappresenta la probabilità che una coppia di record soddisfi la condizione di join. È dunque riferito alla distribuzione di probabilità congiunta.

=== Operatori Fisici per le Operazioni su Set e Multi-Set
Per effettuare operazioni di unione, intersezione e differenza tra due relazioni, rappresentabili per mezzo di multi-set, abbiamo la necessità che gli operatori fisici di nostra implementazione abbiano accesso a dati già *ordinati*. In questo modo possiamo utilizzare tecniche simili a quelle viste per il merge join.

Oltre ai classici operatori abbiamo un operatore speciale che è anche il più semplice dal punto di vista implementativo ossia l'*_UnionAll(O_E,O_I)_* che prende in input due multi-set di record e restituisce il loro multi-set unione. Il costo di questo operatore è semplicemente dato dalla somma dei costi delle due sorgenti: $C = C(O_E) + C(O_I)$.

== Ottimizzazione delle Query Relazionali
Il motivo per cui abbiamo spiegato in dettaglio le varie implementazioni e costi legati ad ogni operatore fisico illustrato è che, dato un piano di accesso logico, il gestore dei piani di accesso deve essere in grado di tradurre questo piano in un piano di accesso fisico efficiente. Questo processo di traduzione è noto come *ottimizzazione delle query* e viene svolto dal modulo *query optimizer* del DBMS che possiamo vedere in @fig:rdbms_internal.

Come abbiamo visto è possibile tradurre una query relazionale in molteplici tipi di piani di accesso fisico, utilizzando operatori diversi a seconda delle strutture dati a disposizioni e delle condizioni specificate sulla query. È dunque di fondamentale importanza riuscire ad individuare il piano di accesso fisico più efficiente per svolgere la query richiesta.

Nel processo di ottimizzazione delle query, il query optimizer divide il compito in due fasi principali.:

- *analisi della query*: in questa fase viene analizzata la correttezza sintattica della query e viene generato un _albero logico_ basato sull'algebra relazionale estesa.
- *trasformazione della query*: l'albero logico prodotto nella fase precedente viene trasformato in un piano logico equivalente ma più *efficiente*.
- *generazione del piano fisico*: il piano logico ottimizzato viene tradotto in un piano di accesso fisico. In questa fase diverse implementazioni fisiche degli operatori logici vengono prese in considerazione e viene scelto il piano fisico con costo minore.

Solo a questo punto è finalmente possibile andare ad eseguire il piano di accesso fisico generato dallo storage engine.

=== Analisi della Query
Durante la fase di analisi della query vengono svolte le seguenti operazioni:

- Analisi lessicale e sintattica della query SQL per verificarne la correttezza.
- Analisi *semantica* della query, per verificare che la query sia semanticamente corretta (fa riferimento a tabelle e attributi esistenti, i tipi di dato sono corretti, ...) e che l'utente abbia i permessi necessari per eseguire la query.
- La condizione *`WHERE`* della query viene riscritta in forma *conjunctive normal form* (CNF) per semplificare le successive fasi di ottimizzazione.
- Una volta riscritta la condizione `WHERE` questa viene ulteriormente semplificata:
  - vengono applicate le regole di equivalenza delle espressioni booleane
  - vengono eliminate le condizioni ridondanti
  - vengono eliminate condizioni contraddittorie (es. $A > 20 and A < 18 eq.triple perp$)
  - vengono trasformate condizioni in modo tale che il `NOT` non appaia scrivendo il complementare della condizione negata (es. $not(A > 20) eq.triple A <= 20$)

Dopo queste trasformazioni
viene generato un albero logico basato sull'algebra relazionale estesa precedentemente introdotta. Per esempio consideriamo la query seguente:

```SQL
SELECT PkEmp, EName
FROM Employee JOIN Department
  ON Employee.FkDept = Department.PkDept
WHERE
  Department.DLocation = 'Pisa' AND Employee.ESalary > 2000;
```

Questa query può essere rappresentata tramite l'albero logico mostrato

#figure(
  image("../images/ch10/logical_tree_query.png", width: 40%),
  caption: "Albero logico della query di esempio",
)<fig_10_logical_tree>

==== Regole di Trasformazione Logica
Andiamo ora a vedere alcune regole che in linea generale possiamo andare a considerare per trasformare un albero logico in un albero equivalente ma più efficiente.

In primo luogo possiamo andare ad utilizzare alcune regole di *semplificazione* delle espressioni algebriche, le elenchiamo di seguito:

- *Eliminazione delle selezioni in cascata*: quando ci troviamo di fronte e più operazioni di selezione concatenate, possiamo andare a fondere queste selezioni in un'unica operazione di selezione con condizione data dalla congiunzione delle condizioni originali: $sigma_(psi_X)(sigma_(psi_Y)(E)) = sigma_(psi_(X Y))(R)$

- *Commutatività di selezione e proiezione*: le operazioni di selezione e proiezione sono commutative tra loro, dunque possiamo scambiare l'ordine in cui queste vengono applicate: $pi^b_Y (sigma_(psi_X)(E)) = sigma_(psi_X)(pi^b_Y(E))$ se $X subset.eq Y$, in caso contrario avremo $pi^b_Y (sigma_(psi_X)(E)) = pi_Y^b (sigma_(psi_X)(pi^b_(X Y)(E))$.

In linea generale possiamo utilizzare il principio di *selection push-down* che consiste nel portare tutte le operazioni di filtraggio il più possibile verso gli operatori di scansione delle relazioni. In questo modo andremo a ridurre il numero di record che dovranno essere processati dagli operatori successivi.


#figure(
  image("../images/ch10/query_optimization.png", width: 60%),
  caption: "Albero logico ottimizzato della query di esempio",
)<fig_10_optimized_logical_tree>

Sempre su questo principio, possiamo andare a riposizionare le operazioni di selezione e *proiezione* in maniera tale che queste vengano eseguite *prima dei* *join*, in questo modo andremo a ridurre il numero di record sui quali effettuare il confronto di uguaglianza tra gli attributi coinvolti nella condizione di join.

Utilizzando le regole appena introdotte possiamo riscrivere l'albero in @fig_10_logical_tree in un albero più efficiente come mostriamo in
@fig_10_optimized_logical_tree.


===== Eliminazione di Clausole Non Necessarie
Sempre in questo processo di ottimizzazione spesso viene considerato il fatto che la selezione di valori *distinti* richiede un costo computazionale maggiore rispetto alla selezione di tutti i valori che soddisfano una query. Spesso ci troviamo davanti a query che utilizzano tale clausola senza che questa sia effettivamente necessaria. Per questo motivo, durante la fase di analisi della query, il query optimizer può andare a rimuovere questa clausola nel caso in cui sia possibile dimostrare che il risultato della query non conterrà mai dati duplicati.

Lo stesso discorso vale per le operazioni di *raggruppamento*, anche in questo caso è necessario che i dati vengano ordinati o partizionati tramite funzioni di hashing. In questo caso potremo procedere con l'eliminazione in due casi:

- la query risponde con dati in un *singolo gruppo*
- la query restituisce *una tupla per gruppo*

In entrambi questi casi non è necessario effettuare operazioni di raggruppamento sui dati, dunque possiamo andare a rimuovere queste operazioni dall'albero logico della query.

Un altro possibile punto di ottimizzazione è quello di cercare il più possibile di non tenere le *subquery* come delle entità separate, in modo tale da includerle nell'albero principale e poterle ottimizzare insieme al resto della query. Per fare questo ci basta sapere che tutti gli operatori (`IN`, `ANY`, `ALL`, ...) possono essere riscritti in termini di `EXISTS` e `NOT EXISTS`, e che questi ultimi possono a volte essere riscritti tramite `JOIN`. In particolare andremo ad utilizzare un normale `JOIN` per riscrivere le condizioni con `EXISTS` e un `OUTER JOIN` per riscrivere le condizioni con `NOT EXISTS`.

Similmente a subquery, grouping e distinct, possiamo anche andare a eliminare operazioni che vanno a creare *viste* di dati. Consideriamo per esempio la seguente query:

```SQL
WITH Technician AS
(
  SELECT PkEmp, EName, Salary
  FROM Employee
  WHERE ERole = 'Technician'
)
SELECT EName, Salary
FROM Technician
WHERE Salary > 3000;
```

Questa può essere semplificata e riscritta nel modo seguente:
```SQL
SELECT EName, Salary
FROM Employee
WHERE ERole = 'Technician' AND Salary > 3000;
```

Esistono anche situazioni in cui questo tipo di ottimizzazione non può essere accorpata alla query principale, per esempio quando la vista viene utilizzata per creare valori aggregati.

```SQL
WITH NoEmployeeByDept AS
(
  SELECT FkDept, COUNT(*) AS NumEmp
  FROM Employee
  GROUP BY FkDept
)
SELECT AVG(NoEmp), FROM NoEmployeeByDept
```
In questo caso abbiamo una query che calcola il numero medio di dipendenti in ogni dipartimento. In questo caso non possiamo andare a rimuovere la vista.

Un'ultima operazione possibile è quella di andare a spostare le operazioni di *raggruppamento* successivamente alle operazioni di *join*. In questo modo andremo a rendere l'operazione di join più leggera.

=== Generazione del Piano Fisico
Dopo aver visto come sia possibile andare a ottimizzare l'albero logico della query, andiamo a vedere come sia possibile tradurre questo albero logico in un *piano di accesso fisico*.

A livello pratico, abbiamo già menzionato il fatto che dato un albero logico è possibile utilizzare molteplici operatori fisici per implementare ogni operazione logica. Per esempio, per effettuare una scansione di una relazione possiamo utilizzare un *table scan*, uno *sort scan* oppure un *index scan*.

In generale quello che accade è che vengono generati diversi piani alternativi e viene fatta una *stima* del costo di ogni piano, per poi scegliere quello con *costo atteso minore*.
Per fare questa stima del costo è necessario conoscere:

- il *costo* di ogni *operatore* fisico
- la *cardinalità* dei risultati *intermedi*
- se i risultati *intermedi* sono *ordinati* o meno

Nel caso in cui nella query da considerare vengano utilizzate operazioni di *join*, ossia vengono utilizzate più relazioni, il numero di possibili piani di accesso fisico diventa estremamente grande. Nello specifico, il problema di dare la soluzione ottima è *esponenziale* nel numero di relazioni coinvolte nella query. Per questo motivo, nella pratica vengono utilizzate tecniche *euristiche*, specie nel caso di query molto grandi.
