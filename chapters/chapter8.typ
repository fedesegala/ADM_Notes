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

=== Funzione di Hashing
La funzione di hashing $H$ è il cuore di questa organizzazione. Si dice che la funzione di hash è *uniforme* nel momento in cui tutti gli indirizzi sono prodotti in modo uniforme nell'intervallo $[0, M-1]$. Si dice che due chiavi $k_1$ e $k_2$ sono *sinonimi* quando $H(k_1) = H(k_2)$, ossia, producono una _collisione_.

Se il numero di collisioni su una pagina è maggiore della capacità di una pagina, ci troveremo in una situazione di *overflow*. Il numero di overflow in generale va ad aumentare il costo delle operazioni di ricerca, dal momento che per uno stesso hash si renderà necessario l'accesso ad un numero elevato di pagine.

Quando una funzione di hashing è ben progettata (80% occupazione delle pagine), possiamo assumere di non avere un numero overflow, dunque ogni operazione di ricerca avrà costo _unitario_. Una tipica funzione di hashing è quella che effettua il *modulo* del valore della chiave rispetto al numero di pagine $M$:

#math.equation(
  block: true,
  numbering: none,
  $
    H(k) = k "mod" M_p
  $,
)

dove $M_p$ è il numero di pagine del file. Chiaramente il valore '80% di page occupancy' è un valore ideale, che non è così immediato ottenere. Questo verrà ulteriormente discusso nella sezione dedicata alla gestione del loading factor.

=== Gestione dell'overflow
Come già citato parlando delle funzioni di hashing, la gestione dell'overflow è di fondamentale importanza per garantire efficienza in lettura. Possiamo gestire l'overflow in diversi modi.

==== Open Overflow (Open Addressing)
In questo approccio i record che non trovano spazio nella pagina designata da $H(k)$ vengono memorizzati in altre pagine libere della zona *primaria*. Si tratta di un approccio estremamente semplice e di facile gestione, il problema sorge nel momento in cui la probabilità di overflow aumenta: diventerà sempre più necessario andare a cercare nelle pagine libere, aumentando così il costo delle operazioni di ricerca.

Un altro importante problema di questo approccio è che, per quanto stiamo risolvendo il problema relativo all'overflow per una dato hash-code, stiamo andando a _rubare_ spazio per record che verranno mappati in altre pagine.

Chiaramente, per quanto questo approccio sia semplice, ha la caratteristica di *degradare velocemente* le prestazioni all'aumentare del numero di record memorizzati.

==== Chained Overflow (Closed Addressing)
Questo approccio prevede di utilizzare una zona di overflow separata dalla zona primaria. L'idea è quella di utilizzare l'ultima parte di ogni pagina per memorizzare l'overflow. Possiamo vedere ogni pagina come divisa in due porzioni. La prima porzione sarà quella utilizzata per memorizzare i record che mappano in quella pagina, mentre la seconda porzione sarà destinata record in eccedenza, l'ultima parte di questa porzione viene a sua volta utilizzata per memorizzare un puntatore alla pagina di overflow successiva. Questo meccanismo viene mostrato in @fig:chained_overflow.

#figure(
  image("../images/ch08/chained overflow.png", width: 50%),
  caption: "Gestione dell'overflow con chained overflow",
)<fig:chained_overflow>

Questo approccio consente di andare, pur riducendo lo spazio associato ad ogni pagina primaria, di riservare una porzione di pagina ai record che dovrebbero essere effettivamente memorizzati in quella pagina.

==== Gestione completamente separata
In questo approccio, che è esattamente quello illustrato in @fig:hash_workflow, viene prevista una zona di overflow completamente separata dalla zona primaria. In questo caso ogni pagina di overflow contiene record che non hanno trovato spazio nella zona primaria. Tuttavia è comunque necessario definire in quale maniera i record in overflow vengono memorizzati, il che risulta in un problema simile a quello dell'organizzazione primaria.

=== Loading Factor
Dato il numero di pagine $M$ e la capacità di una pagina $c$, possiamo definire il *loading factor* $d = N / (M dot c)$, dove $N$ è il numero di record memorizzati. Sostanzialmente si tratta di una metrica che rappresenta la percentuale media di elementi memorizzati in ogni pagina.

Come si può immaginare, un loading factor elevato implica una maggior probabilità di overflow e un conseguente aumento del costo delle operazioni di ricerca.

Il grafico in @fig:loading_factor mostra come il costo medio delle operazioni di ricerca vada ad aumentare all'aumentare del loading factor, per i diversi approcci di gestione dell'overflow.

#figure(
  image("../images/ch08/loadingfactor.png", width: 70%),
  caption: "Costo medio delle operazioni di ricerca in funzione del loading factor",
)<fig:loading_factor>


La voce _coalesced list_ sta a rappresentare  un approccio in cui vengono messi insieme elementi appartenenti a diverse 'sorgenti di overflow'.

=== Costi dell'approccio
Nel caso di ricerca di una *singola chiave* una scelta ragionevole dei parametri del nostro sistema (funzione di hash, gestione dell'overflow, loading factor) ci permette di ottenere un costo medio per operazione di ricerca *prossimo* a *1 page access*. Per ottenere tali risultati alcuni valori tipicamente utilizzati sono un loading factor $d <0.7, c >> 10$.

Come già anticipato non è possibile andare a ricercare valori in *intervalli*, dal momento che non esiste un ordinamento trai valori memorizzati.

Per quanto riguarda gli *inserimenti* e le *cancellazioni*, queste operazioni hanno il costo di 1 operazione in lettura e 1 operazione in scrittura, dunque hanno costo costante.

=== Riorganizzazione della struttura
Prima di spiegare come avviene questo delicato processo, è importante sottolineare che questa viene effettuata in situazioni abbastanza particolari:

- la quantità di *overflow* è particolarmente elevata (nel caso in cui l'area primaria è utilizzata per gli overflow, altrimenti non serve)
- quando un numero significativo di record sono stati *cancellati*, e dunque è necessaria una *compattazione* dei record

Per effettuare la riorganizzazione si utilizza un file _temporaneo_ su cui verranno copiati tutti i record. Dopo aver copiato tutti i record verrà effettuata un'operazione di *bulk load*:

- il file temporaneo viene ordinato in base all'hash code $H(k)$
- caricamento dei record che non causano overflow in ciascun hash file
- caricamento dei record in overflow nelle pagine di overflow

== Hashing Dinamico
Sebbene l'*hashing* *statico* sia un approccio semplice che può funzionare in maniera estremamente efficiente a _determinate condizioni_, il problema è che nel momento in cui la situazione inizia a degradare, questa arriva ad essere catastrofica molto rapidamente, richiedendo una riorganizzazione completa della struttura.

L'idea è che, dal momento che la riorganizzazione *non è evitabile* in alcun modo o, per meglio dire, è probabile che nel corso del tempo sarà un processo necessario, vorremmo quantomeno evitare di dover fermare l'intero sistema per effettuare questa operazione.

Ci piacerebbe dunque avere un sistema che ci permetta di eseguire in maniera preventiva alcune delle operazioni necessarie per la riorganizzazione, in modo tale che, rendendo leggermente più lenta l'amministrazione ordinaria, possiamo garantire un sistema più leggero nei confronti della riorganizzazione. Questa è proprio l'idea che sta alla base degli *hash file dinamici*. Abbiamo a disposizione due principali metodologie:

- hashing dinamico che utilizza strutture *ausiliarie*, come ad esempio il _virtual hashing, extensible hash, dynamic hash_.
- hashing dinamico *senza* strutture *ausiliarie*, come ad esempio il _linear hashing_ o l'_hashing a spirale_.

In questa sezione andremo ad affrontare unicamente hashing lineare e virtuale.

=== Hashing virtuale
Come sappiamo, il problema della riorganizzazione consiste nel dover riorganizzare un *file intero alla volta*. Immaginiamo di non ammettere overflow, ma di permettere che, nel momento in cui ci troveremmo di fronte a uno sforamento, possiamo creare più spazio per i record. Invece però di andare a creare più spazio per tutti i record, andremo a creare più spazio solo per i record che mapperebbero in una pagina con overflow.

Di seguito mostriamo il workflow di questo approccio:

+ Il file in memoria contiene inizialmente un numero $M$ di pagine contigue con capacità $c$. Ogni pagina è identificata da un indirizzo nell'intervallo $[0, M-1]$.
+ Un bit vector $cal(B)$ viene utilizzato per tenere traccia delle pagine che contengono almeno un record al loro interno
+ Inizialmente la funzione di hash $H_0$ è utilizzata per mappare ogni chiave $k$ in un indirizzo $H_0(k) in [0, M-1]$. Se dovesse venir generato un overflow:
  - il numero di pagine continue viene raddoppiato, creando $M$ nuove pagine
  - viene creata una nuova funzione di hash $H_1$ tale che $m in [0, 2M-1]$
  - la funzione $H_1$ viene applicata alla chiave $k$ e a tutti i record nella pagina $m$ che ha causato overflow in modo da distribuire i record tra $m$ e $m'$

In caso di overflow tutti i record nelle pagine diverse dalla pagina $m$ non verranno in alcun modo toccati. In questo modo l'operazione di riorganizzazione viene limitata a un sottoinsieme di pagine, riducendo notevolmente il costo dell'operazione. Chiaramente questo approccio richiede di utilizzare una serie di funzioni $H_0, ... H_r$, dove in generale $H_r$ produce pagine appartenenti all'intervallo $[0, 2^r M - 1]$. Questo meccanismo viene spiegato di seguito.


#figure(
  image("../images/ch08/virtualHash.png", width: 100%),
  caption: "Esempio di gestione di overflow in una situazione di virtual hashing.
  Nota Bene: il bit-vector viene mostrato ma è da considerare presente.",
)<fig:virtual_hashing>

Per andare a gestire la ricerca di un record data una chiave $k$ possiamo far riferimento al seguente algoritmo:

```python
def PageSearch(r, k: int) -> int:
  if r < 0
  # l'algoritmo ha provato tutte le funzioni di hash senza successo
    raise Exception("Inexistent key")
  elif B(H(r,k)) == 1:
    return H(r,k)
  else:
    return PageSearch(r-1, k) # ricerca tramite hash precedente

# esempio di utilizzo
page = PageSearch(r_max, key) # r_max è il massimo hash level in uso
```
#remark[
  Per quanto possa sembrare superflua, il mantenimento del bit vector $cal(B)$ rende possibile evitare di accedere a pagine vuote, riducendo notevolmente il costo delle operazioni di ricerca.
]

In riferimento a @fig:virtual_hashing, immaginiamo di voler ora inserire la chiave $3343$. Andremo in primo luogo a calcolare $H_1(3343) = 11$. Dal momento che la pagina 11 ha indicatore a 0, andremo a calcolare $H_0(3343) = 4$. Se la pagina 4 fosse vuota, potremmo semplicemente andare ad aggiungere il nuovo valore a questa, ma essendo piena, andremo a ricalcolare $H_1$ su tutti gli elementi della pagina, andando a distribuire i record tra la pagina 4 e la pagina 11, segnalando inoltre che la pagina 11 ora contiene dei record nel bit-vector $cal(B)$.

#remark[
  Possiamo notare che in realtà, andando a tenere traccia dell'occupazione della pagina, possiamo andare a *recuperare* un *record* in *un* *solo* *accesso* a pagina, questo perché, utilizzando le hash function da quella di ordine maggiore, possiamo essere sicuri che se una pagina è occupata, il record che stiamo cercando si trova sicuramente in quella pagina.
]

=== Hashing Lineare
Al contrario dell'hashing virtuale, nel quale l'obiettivo è quello di evitare l'avvenimento di overflow, nell'hashing lineare l'obiettivo è quello di andare a regolamentare la politica con cui questo viene gestito. L'idea è quella di andare a aumentare il numero di pagine non appena abbiamo un overflow. Di seguito mostriamo il flusso operativo di questo approccio:

- Inizialmente vengono allocate $M$ pagine continue con capacità $c$
- La funzione di hash iniziale $H_0$ è tale che $H_0(k) = k "mod" M$
- Viene inizializzato un puntatore $p=0$ che punta alla prossima pagina da *splittare*
- Quando si verifica un overflow nella pagina $m = H_i(k)$:
  - se $m = p$, viene effettuato uno *split* della pagina $p$, riorganizzando i record con la funzione $H_{i+1}$
  - se $m > p$, viene creata mantenuta una catena di overflow per la pagina $m$ e viene aggiunta una nuova pagina vuota alla fine del file che rappresenta lo split della pagina $p$, nuovamente i dati verranno riorganizzati
  - se $m < p$, non serve effettuare alcun tipo di split dal momento che la pagina è già stata 'splittata' precedentemente


#figure(
  image("../images/ch08/linear_hash_1.png", width: 100%),
  caption: "Posizione di partenza per linear hashing",
)<fig:linear_hash_start>

@fig:linear_hash_start mostra una possibile situazione di partenza per il nostro scenario di linear hashing. Ipotizziamo che siano stati inseriti dei record, rispettivamente con valore 569 e 563, i cui hash sono $H_0(569) = 2$, $H_0(563) = 3$. Chiaramente guardando alla situazione illustrata si verificheranno due due overflow con due conseguenti split e riorganizzazioni delle pagine 0 e 1. Questo viene rappresentato in @fig:linear_hash_after_two_splits.



#figure(
  image("../images/ch08/linear_hash_2.png", width: 100%),
  caption: "Situazione dopo due split in linear hashing",
)<fig:linear_hash_after_two_splits>

Ipotizziamo di voler andare ora ad aggiungere la chiave 3820, il cui $H_0(3820) = 5$. Andremo a creare una *catena di overflow* sulla pagina 5 e a a effettuare uno split della pagina due, riorganizzandone i valori andando a eliminare l'overflow per quella pagina. Questo viene mostrato in @fig:linear_hash_after_inserting_3820.

#figure(
  image("../images/ch08/linear_hash_3.png", width: 100%),
  caption: "Situazione dopo l'inserimento di 3820 in linear hashing",
)<fig:linear_hash_after_inserting_3820>

Di seguito mostriamo l'algoritmo per la ricerca di una chiave $k$ tramite linear hashing:

```python
def SearchPage(p, k: int) -> int:
  if H_0(k) < p:
    return H(1, k)
  else:
    return H(0, k)
```

Dopo che si saranno verificati $M$ overflow e conseguenti split, il puntatore $p$ tornerà ad essere 0 e le funzioni di hash saranno sovra-scritte, ossia $H_0 <- H_1$, $H_2 = k "mod" 2^2 M$, e così via.

Nonostante questo approccio goda di ottimi costi medi, e di una buona gestione dell'occupazione dello spazio è ancora impossibile effettuare ricerche su intervalli di valori, è inoltre difficile valutare le performance nel caso peggiore.


== Strutture basate su B+ Tree
Introduciamo in questa sezione quella che è la soluzione più utilizzata in generale, dal momento che è in grado di bilanciare in maniera ottimale l'utilizzo dello spazio garantendo anche *ricerche su intervalli*. La soluzione in questione è fornita dalla struttura *B+ Tree*.

Si tratta a di un albero *multi-way*, ossia un albero in cui ogni nodo può avere più di due figli. Si rende infatti necessario aumentare il branching factor rispetto all'albero binario che non è facilmente paginabile.

All'interno di questa struttura i record vengono memorizzati in *pagine foglia*, mentre tutti i nodi interni contengono valori chiave per *direzionare la ricerca* verso le pagine foglia corrette. Se l'*ordine* (o branching factor di ogni nodo) è $m$, ogni nodo conterrà al suo interno al massimo $m-1$ elementi. Il minimo numero di elementi in un nodo è invece $ceil(m/2) - 1$.

Un'importante proprietà di questo tipo di alberi è che _tutte le pagine foglia_ si trovano allo _stesso livello_ di profondità. Questo garantisce che tutte le ricerche abbiano lo stesso (equo) costo.

#remark[
  Il numero minimo di elementi in un nodo è necessario per garantire la proprietà di *bilanciamento*. Questo si rivela di fondamentale importanza per garantire che le stime dei costi delle operazioni siano veritiere e affidabili anche nei casi pessimi.
]

#figure(
  image("../images/ch08/b+tree.png", width: 70%),
  caption: "Esempio di B+ Tree di ordine 4",
)<fig:bplus_tree>

Il fatto che distingue fondamentalmente un B+ Tree da un B-Tree è che in un B+ Tree tutti i record sono memorizzati in nodi foglia, mentre i nodi interni contengono informazioni per il 'direzionamento' della ricerca. Questo comporta che nel momento in cui vogliamo andare a scorrere tutti i nodi foglia, possiamo farlo in maniera estremamente efficiente, dal momento che questi nodi sono collegati tra di loro tramite puntatori. Questo rende i B+ Tree estremamente efficienti per ricerche su intervalli di valori, come mostrato in @fig:bplus_tree.

=== Ricerca di una chiave
Nel caso di un B-Tree se avessimo voluto cercare tutti i valori inferiori inferiori a 12 in @fig:bplus_tree, avremmo dovuto seguire il primo puntatore del nodo radice, un poi, una volta terminato, tornare alla radice per seguirne il secondo valore. Utilizzato un B+ Tree abbiamo invece la possibilità di scendere il primo puntatore utile e, dal momento che le foglie sono ordinate secondo un attributo (*sequenzialità*), scorrere i collegamenti tra le pagine foglia evitando di dover risalire l'albero ogni volta.

Questa struttura spesso il nome di *index-organized table* dal momento che l'intera tabella viene memorizzata all'interno della struttura ad albero.

È molto facile vedere come la ricerca di una *range di valori* $[k_1, k_2]$ possa essere effettuata in maniera molto efficiente, andando a cercare il primo valore $k_1$ e scorrendo le pagine foglia fino a raggiungere il valore $k_2$.

#remark[
  Possiamo in un certo senso vedere la struttura dei nodi interni del B+ Tree come una sorta di *indice multi-livello* che ci permette di localizzare in maniera efficiente le pagine foglia.
]

=== Inserimento di una chiave
Nel momento in cui volessimo andare ad inserire una nuova chiave $k$ all'interno del B+ Tree, distinguiamo due casi:

- la pagina foglia in cui dovrebbe essere inserita la chiave $k$ ha spazio sufficiente per inserirla: in questo caso andremo semplicemente ad inserire la chiave nella pagina foglia, mantenendo l'ordinamento dei valori al suo interno.
- la pagina foglia in cui dovrebbe essere inserita la chiave $k$ non ha spazio a sufficienza: andiamo di seguito a esplorare come avviene questa delicata operazione.

Possiamo avere due tipologie di overflow su un nodo dell'albero da gestire:

- *overflow* su una *pagina foglia*: in questo caso il nodo foglia viene diviso, il primo nodo conterrà $ceil(M/2)-1$ chiavi, mentre il secondo conterrà le chiavi rimanenti. Il nodo padre di questo nodo foglia si vedrà aggiunto il primo elemento della foglia di destra

- *overflow* su un *nodo intermedio*: in questo caso, analogamente a quanto avviene per le pagine foglia, il nodo intermedio viene diviso in due nodi, con il primo che conterrà $ceil(M/2)-1$ chiavi. Di nuovo la più piccola delle chiavi del nodo di destra verrà promossa al nodo padre

Supponiamo di avere un B+ Tree di ordine $m=3$, questo significa che ogni nodo può contenere al massimo 2 chiavi e 3 puntatori. Ipotizziamo che questo albero sia inizialmente vuoto e che vogliamo andare ad inserire le chiavi 3, 10, 7, 15, 20, 13 in questo ordine.

Dopo l'inserimento delle chiavi 3 e 10 la situazione sarà quella mostrata di seguito, con entrambe le chiavi memorizzate nella stessa pagina foglia e nessun nodo intermedio.

#align(center)[
  #image("../images/ch08/b+tree_insertion1.png", width: 20%)
]

Ipotizziamo ora di dover inserire la chiave 7. Questa dovrebbe essere inserita tra 3 e 10, ma la pagina foglia non ha sufficiente spazio. È quindi necessario effettuare uno *split* della pagina foglia. Per capire come dividere i valori nelle foglie di solito andiamo a mettere $ceil(M/2)-1$ nodi a sinistra e i nodi rimanenti nel nodo di destra. Dal momento che non abbiamo nodi intermedi per gestire il flusso di ricerca, andremo ad inserire un nodo intermedio che conterrà il valore di chiave più piccolo del nodo di destra, in questo caso 7. La situazione dopo l'inserimento della chiave 7 sarà dunque la seguente:
#align(center)[
  #image("../images/ch08/b+tree_insertion2.png", width: 40%)
]

Volendo ora inserire il 15, chiaramente questo andrà inserito nella pagina voglia di destra. Nuovamente sarà necessario operare uno split, dal momento che la pagina foglia non ha sufficiente spazio. Dopo aver effettuato lo split ci troveremo con due nuovi nodi foglia, uno contenente unicamente il valore 7 e uno contenente i valori 10 e 15. Dopo questo passaggio è inoltre necessario aggiungere al nodo intermedio precedente (che è anche la radice) un nuovo valore di chiave, che sarà il 10. Questo viene mostrato nell'immagine che segue:
#align(center)[
  #image("../images/ch08/b+tree_insertion3.png", width: 70%)
]

È ora il momento di aggiungere la chiave 20. Questa andrà inserita nell'ultima pagina foglia ma, non essendo disponibile spazio sufficiente, sarà necessario effettuare un nuovo split. Dopo aver effettuato lo split, andremo ad aggiungere il valore 15 al nodo intermedio, il quale non avendo a sua volta sufficiente spazio, dovrà essere anch'esso diviso. L'inserimento della chiave 13, andrà in seguito a riempire una pagina con spazio sufficiente, dunque non sarà necessario effettuare alcuno split. Di seguito mostriamo la situazione dopo l'inserimento di tutti le chiavi.
#align(center)[
  #image("../images/ch08/b+tree_insertion4.png", width: 90%)
]

=== Cancellazione di una chiave
Come possiamo immaginare, la cancellazione viene tipicamente operata solamente sulle pagine foglia. È tuttavia necessario che un nodo non vada in '*underflow*', ossia che non contenga meno della soglia minima di elementi, che ricordiamo essere $ceil(M/2)-1$.

In questo caso sarà necessaria una riorganizzazione della struttura. Per fare questo abbiamo tipicamente a disposizione due operazioni:

- *rotazione*: viene tipicamente utilizzata nel momento in cui un nodo fratello ha più del numero minimo di elementi. In questo caso andremo a prendere in prestito un elemento dal nodo fratello, aggiornando di conseguenza il nodo padre
- *merging*: viene utilizzata quando il fratello immediatamente successivo ha esattamente il minimo degli elementi. In questo caso andremo a fondere i due nodi, eliminando il puntatore al nodo fratello dal nodo padre. Questa operazione può causare underflow anche nel padre, il quale andrà gestito in maniera ricorsiva.

=== Profondità di un B+ Tree
Come possiamo immaginare, e come abbiamo anche visto studiando le strutture ad albero in generale, la *profondità* di questo albero va a determinare in maniera significativa il costo delle operazioni di ricerca. Possiamo andare a stimare la profondità dell'albero andando a stabilire un lower bound (caso _migliore_) e un upper bound (caso _peggiore_):

#math.equation(
  block: true,
  $
    log_m(N + 1) <= h <= log_(ceil(m/2))((N + 1)/2)
  $,
)

Ovviamente il caso peggiore va a verificarsi quando ogni nodo è occupato dal numero minimo di elementi, mentre il caso migliore si verifica quando ogni nodo è completamente pieno.

==== Applicazioni Pratiche dei B+ Tree
Andiamo a vedere alcuni valori tipici dei parametri per la costruzione di un B+ Tree in applicazioni pratiche. Normalmente l'ordine $m$ di un albero è un valore $in [100,200]$, questo permette di avere alberi con un fill-factor che si aggira attorno al 67% circa.

Questi valori consentono di avere alberi strutturati in modo tale che la parte dell'indice (*nodi intermedi*) sia ospitabile all'interno del buffer pool, consentendo così di ridurre notevolmente il numero di accessi a disco necessari per le operazioni di ricerca.

== Indici
Dopo aver introdotto alcune tipologie di organizzazioni primarie per i file, andiamo a vedere da questo momento in poi le organizzazioni *secondarie*, ossia strutture dati basate su *indici*.

#definition(title: "Indice")[
  Un *indice* è una collezione di record con campi $[k_i, r(k_i)}$, dove $k_i$ è una chiave e $r(k_i)$ è un *record identifier* (RID) per il record con chiave $k$.
]

Utilizzare una struttura secondaria come un indice, permette di non dover modificare il riferimento fisico dei record nel file principale. Questo ci consente di poter utilizzare organizzazioni primarie più semplici ed economiche, come quella seriale (heap file), dal momento che la gestione dell'ordinamento e della localizzazione dei record viene demandata all'indice secondario.

Dato un file con molteplici record, è possibile stabilire diversi tipi di indici, ognuno dei quali con una chiave di ricerca differente.
Il fatto di poter utilizzare più indici su uno stesso file consente di poter effettuare ricerche efficienti su condizioni differenti, senza dover modificare la struttura primaria del file. Questo sarebbe impossibile nel caso di organizzazioni primarie basate su alberi o heap file sequenziale, dal momento che in questi casi l'ordinamento fisico dei record è vincolato alla chiave primaria.

==== Indici Clustered e Unclustered
Sebbene si tratti di una struttura secondaria, potrebbe capitare che in maniera casuale, l'indice vada più o meno a ricalcare la struttura ordinata di un file primario. In questi casi si parla di *indici clustered*, in caso contrario si parla di *indici unclustered*.

#figure(
  image("../images/ch08/index.png", width: 85%),
  caption: "Esempio di indice clustered (sinistra) e unclustered (destra) data una tabella",
)<fig:clustered_unclustered_index>

==== Indici Densi e Sparsi
Un'altra importante distinzione che è possibile fare è quella tra indici *densi* e *sparsi*. Un indice è detto _denso_ quando il numero di entry è uguale al numero di record che sono memorizzati in un file. Al contrario un indice _sparso_ contiene un sottoinsieme delle entry del file primario.
Un esempio classico di indice sparso è quello indotto da un B+ Tree, in cui le entry sono memorizzate unicamente nelle pagine foglia dell'albero e utilizziamo come indice la struttura dei nodi interni dell'albero. Un esempio di indice _denso_ si può trovare in entrambi i casi di @fig:clustered_unclustered_index, in cui ogni record della tabella (file) ha una entry nell'indice.
