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
Nello scorso capitolo abbiamo visto come i file possono essere organizzati in maniera tale da rendere più efficienti le operazioni di accesso ai dati sulla base di alcuni attributi. Come abbiamo visto possiamo fornire delle organizzazioni primarie, che possono essere statiche o dinamiche, oppure degli *indici* che permettono di accedere ai dati in maniera efficiente anche quando l'organizzazione primaria non è strutturata per soddisfare in maniera efficiente le richieste delle query.

Tutto ciò che abbiamo visto nel capitolo precedente si basa su strutture dati *mono-dimensionali*, ovvero strutture che permettono di organizzare i dati sulla base di un singolo attributo. Tuttavia nella maggior parte dei contesti avremo in realtà a che fare con dati che sono per loro natura *multi-dimensionali*.

Un esempio molto comune di dati multi-dimensionali sono i dati _spaziali_, ovvero dati che rappresentano oggetti nello spazio, come ad esempio punti, linee, poligoni, ecc. Questi dati sono caratterizzati da più attributi che rappresentano le coordinate spaziali (ad esempio latitudine e longitudine) e spesso è necessario effettuare query che coinvolgono più di un attributo (ad esempio trovare tutti i punti all'interno di una certa area geografica).

È necessario prestare particolare importanza alla maniera in cui vengono indicizzati i dati su più attributi: immaginiamo per esempio di avere un indice di primo livello su un singolo attributo (es. età) e un indice di secondo livello su un altro attributo (es. reddito) che mantiene un ordinamento però sulla base dei valori del primo attributo. In questo caso se volessimo effettuare una query che coinvolge unicamente il secondo attributo (ad esempio trovare tutte le persone in un certo intervallo di  reddito) l'indice non sarebbe di alcun aiuto, in quanto l'ordinamento è basato sul primo attributo.
In altri casi potrebbe essere necessario effettuare delle query che coinvolgono più attributi senza però avere una chiara gerarchia tra di essi (ad esempio trovare tutti i punti in un'area rettangolare definita da due coordinate).

==== Requisiti per le Organizzazioni Multidimensionali
Prima di andare a vedere alcuni degli approcci più comuni utilizzati è necessario capire come vorremmo organizzare le nostre gestire le nostre organizzazioni in caso di gestione di dati multi-dimensionali.

- per quanto riguarda le organizzazioni primarie, vorremmo fare in modo da dividere i dati in partizioni che raggruppano insiemi di dati che verranno acceduti assieme

- per quanto riguarda le organizzazioni secondarie vorremmo comprendere in che modo dividere le 'righe' dell'indice trai nodi foglia dell'indice

Per rispondere a questo tipo di domande è quanto mai utile andare ad analizzare il *tipo di query* che vogliamo andare a supportare nei nostri sistemi, in modo da poter scegliere l'organizzazione più adatta alle nostre esigenze. Le query più comuni che vogliamo andare a supportare sono:

- ricerca di *punti* o di *regioni* specifiche: si tratta dell'equivalente delle _query di uguaglianza_ nel caso monodimensionali. In sostanza vogliamo andare a verificare che un punto specifico (o una regione, ossia un certo insieme di dati specifico) sia presente nei dati.

- ricerca su *range spaziali*: si tratta dell'equivalente delle query di intervallo nel caso monodimensionale. Vogliamo in questo caso andare a cercare tutti i punti che ricadono in un (iper) rettangolo o in una (iper) palla

- ricerca dei *k-nearest neighbors*: in questo caso vogliamo andare a cercare i k punti più vicini ad un punto specifico. Si tratta di una query molto comune in ambito spaziale e di machine learning.

== Tipologie di Organizzazioni Multidimensionali
Esistono diversi modi per organizzare i dati multi-dimensionali, di seguito elenchiamo alcune delle metodologie più comuni.

===== Linearizzazione
La prima tecnica che possiamo provare ad utilizzare è quella di *linearizzare* lo spazio multi-dimensionale convertendolo in un nuovo spazio uni-dimensionale. In questo caso, abbiamo la necessità di costruire un *ordinamento totale* sui dati. Si rende dunque necessario trasformare i dati in una singola dimensione, in modo tale da poter utilizzare le strutture dati monodimensionali viste nel capitolo precedente.

Ovviamente questo approccio presenta il problema di non garantire che dati diversi vengano mappati in punti dello spazio diversi, ovvero si possono avere delle *collisioni* tra punti diversi che vengono mappati nello stesso punto dello spazio uni-dimensionale.

#figure(
  image("../images/ch09/linearization.png", width: 60%),
  caption: "Esempio di linearizzazione dello spazio bidimensionale",
)<fig_linearization>

Possiamo notare come nella precedente immagine ci si possa immaginare di avere una linea che va ad attraversare tutte le possibili posizioni nello spazio bidimensionale (ipotizzando che sia discreto) e che vada a mappare ogni punto in base all'ordine in cui questa linea va a attraversare i punti stessi. Un'altro modo per applicare questa tecnica è quello andare a stabilire una *gerarchia* tra gli attributi.
Ad ogni modo, vorremmo fare in modo che i punti che sono vicini nello spazio multi-dimensionale rimangano vicini anche nello spazio uni-dimensionale, nel concreto, vorremmo che la curva che riempie lo spazio eviti di fare salti troppo ampi tra punti molto vicini. Questo è proprio ciò che otteniamo in @fig_linearization.

===== Partizionamento dello Spazio
Un altro approccio è quello di *partizionare* lo spazio in diverse regioni e andare a memorizzare assieme quegli elementi che sono appartenenti alla stessa partizione. Un esempio di come questo avviene si può osservare in @fig_09_partitioning, dove lo spazio bidimensionale viene partizionato in regioni distinte.

#figure(
  image("../images/ch09/space_partitioning.png", width: 50%),
  caption: "Esempio di partizionamento dello spazio bidimensionale",
)<fig_09_partitioning>

===== Albero di Ricerca Generalizzato
Questo approccio è molto simile al precedente, ma invece di partizionare tutto lo spazio di ricerca, si dividono i dati in *regioni* che ammettono *overlapping*. Possiamo vedere questo approccio illustrato in @fig_generalized_tree_search.

#figure(
  image("../images/ch09/generalized_treesearch.png", width: 40%),
  caption: "Esempio di albero di ricerca generalizzato",
)<fig_generalized_tree_search>


== B+ Tree Multidimensionali
Una possibile soluzione per indicizzare dati multi-dimensionali è quella di provare a usare un B+ Tree mantenendo un *ordinamento lessicografico* sui valori degli attributi. Ad esempio, se abbiamo due attributi A e B, potremmo ordinare i dati prima per A e poi per B. In questo modo, quando effettuiamo una query che coinvolge entrambi gli attributi, possiamo navigare nell'albero seguendo l'ordinamento lessicografico.

#figure(
  image(
    "../images/ch09/01_b+tree.png",
    width: 65%,
  ),
  caption: "Esempio di B+ Tree con ordinamento lessicografico",
)<fig_09_01>

@fig_09_01 mostra un esempio di come si possa utilizzare un B+ Tree per indicizzare dati sulla base di un attributo A e un attributo B utilizzando un ordinamento lessicografico tra i due attributi. Andiamo in sostanza a definire una *gerarchia* trai due attributi, dove il secondo attributo serve a _risolvere la parità_ sul primo attributo. Questo approccio va proprio ad implementare il concetto di *linearizzazione* mostrato in precedenza.

=== Vantaggi e Svantaggi
Questo approccio per quanto utile nel caso in cui si vogliano effettuare query *puntuali*. Funziona bene anche nel caso in cui vogliamo andare a effettuare ricerche su *range per il primo attributo*. Per il secondo attributo questo approccio risulta molto meno utile in quanto l'ordinamento è influenzato dal primo attributo.

Altro svantaggio di questo approccio è che non consente di effettuare query del tipo *k-nearest neighbors* in maniera efficiente, in quanto l'ordinamento lessicografico non riflette la distanza spaziale tra i punti.


=== Space Filling Curves
In questa sezione andiamo a mostrare come le curve di riempimento dello spazio variano a seconda della gerarchia che andiamo ad utilizzare per mappare lo spazio multi-dimensionale in uno spazio uni-dimensionale in un Bè tree.

Vedremo come la scelta dell'ordinamento tra gli attributi vada ad influenzare in maniera sostanziale la qualità della mappatura nello spazio mono-dimensionale.

Iniziamo ad analizzare l'effetto dell'*ordinamento lessicografico* che abbiamo ipotizzato, ossia dove l'attributo $A_1$ ha priorità sull'attributo $A_2$. In questo caso la curva di riempimento dello spazio sarà come quella in  @fig_09_lexicographic.

#figure(
  image("../images/ch09/lexicographic_spacefilling.png", width: 50%),
  caption: "Curva di riempimento dello spazio con ordinamento lessicografico",
)<fig_09_lexicographic>

Possiamo notare che in questo caso la curva tende a fare dei *salti molto ampi* in corrispondenza del cambio di valore dell'attributo $A_1$. Il problema di questo tipo di mapping si mostra nel senso che a fronte di una leggerissima perturbazione dei valori di $A_1$ possiamo avere dei cambiamenti molto ampi nella posizione nello spazio uni-dimensionale.

In alternativa all'ordinamento lessicografico possiamo utilizzare un ordinamento che permette di ottenere dei salti più corti per alcuni valori, mentre per altri valori si avranno dei salti comunque grandi, addirittura più grandi rispetto all'ordinamento lessicografico. Questo viene chiamato *ordinamento diagonale* e viene mostrato in @fig_09_diagonal.

#figure(
  image("../images/ch09/diagonal_spacefilling.png", width: 50%),
  caption: "Curva di riempimento dello spazio con ordinamento diagonale",
)<fig_09_diagonal>

Per ottenere tale ordinamento si utilizza la *somma delle due coordinate*. Possiamo notare come in questo caso i salti siano più bilanciati, anche se comunque si hanno dei salti molto ampi in corrispondenza di alcune regioni dello spazio (specialmente sulla diagonale).

Un'alternativa a questo tipo di curva è la *Morton space filling curve* (o Z-order), che viene mostrata in @fig_09_morton.

#figure(
  image("../images/ch09/morton_curve_1.png", width: 50%),
  caption: "Curva di riempimento dello spazio con ordinamento Morton (Z-order)",
)<fig_09_morton>

Il motivo per cui questa curva è chiamata Z-order è che l'elemento di base è una 'Z', e ci muoviamo nello spazio seguendo questa forma in maniera ricorsiva a seconda della risoluzione desiderata. Di seguito vediamo alcuni esempi:

#figure(
  grid(
    columns: (50%, 50%),
    rows: (auto, auto),
    column-gutter: (-25%),

    image("../images/ch09/morton2.png", width: 50%), image("../images/ch09/morton3.png", width: 50%),
    image("../images/ch09/morton4.png", width: 50%), image("../images/ch09/morton5.png", width: 50%),
  ),
  caption: "Varianti della curva di Morton a diverse risoluzioni",
)<fig:morton_listing>

Ciò che accade aumentando il livello di ricorsività è che il numero di 'Z' che la curva disegna aumenta esponenzialmente, andando a coprire lo spazio in maniera sempre più dettagliata. In particolare pensiamo alle coordinate come se fossero rappresentabili tramite numeri binari, possiamo rappresentare ogni punto dello spazio coperto dalla curva tramite una sequenza alternata di bit presi da un attributo e dall'altro. Questo concetto è mostrato in @fig_09_morton_bits.

#figure(
  image("../images/ch09/morton_bit_representation.png", width: 70%),
  caption: "Rappresentazione binaria dei punti nello spazio secondo la curva di Morton",
)<fig_09_morton_bits>

Questa proprietà rende il nostro sistema ancora più efficiente dal momento che rende il calcolo di operazioni bit-wise molto semplice ed efficiente.

Un'altra tecnica molto utilizzata è quella di data dalla *Peano space filling curve*. Il vantaggio principale di questa curva è quello che, con livelli di ricorsività molto elevanti la grandezza di 'salto' tra punti particolarmente lontani è sempre limitata, rendendo dunque questo approccio più robusto e stabile. Vediamo questo approccio implementato in @fig_09_peano.


#figure(
  image("../images/ch09/peano.png", width: 90%),
  caption: "Curva di riempimento dello spazio con ordinamento Peano con diversi livelli di ricorsività",
)<fig_09_peano>

Un altra curva estremamente utile e particolarmente efficiente da calcolare tramite un algoritmo ricorsivo è la *Hilbert space filling curve*. Il pattern di base di questa curva è una 'U'. Vediamo come questa curva si comporta in @fig_09_hilbert.

#figure(
  image("../images/ch09/hilbert.png", width: 50%),
  caption: "Curva di riempimento dello spazio con ordinamento Hilbert",
)<fig_09_hilbert>

== Tecniche di Space Partitioning
In questa sezione andiamo a vedere quali tecniche sono utilizzate in contesti pratici per andare a gestire lo spazio multidimensionale tramite *partizionamento*.
Abbiamo due quesiti principali da provare a risolvere in questo contesto:

- come partizionare lo spazio in regioni contigue senza sovrapposizioni in modo che contengano record che andrebbero memorizzati nella stessa pagina
- come trovare in maniera rapida ed efficiente la regione dello spazio partizionato che contiene i punti che soddisfano una determinata query

=== Point Region Quadtree
La prima alternativa che abbiamo a disposizione è il *point region quadtree*. Si tratta di un approccio molto simile a quello degli alberi binari. Sappiamo che in un albero binario ogni nodo divide lo spazio in due metà: in parole povere, possiamo immaginarci che ci sia una soglia, e che tutti i valori minori di questa soglia vadano a sinistra, mentre tutti i valori maggiori vadano a destra.

Nel caso di un quadtree (albero quaternario), ogni nodo divide lo spazio in base a entrambi gli attributi (nel caso in cui lo spaio sia bidimensionale). In questo caso ogni nodo avrà quattro figli, ognuno dei quali rappresenta una delle quattro regioni in cui lo spazio viene diviso.

#figure(
  image("../images/ch09/quadtree.png", width: 60%),
  caption: "Esempio di Point Region Quadtree dato un dataset",
)<fig_09_pr_quadtree>

Il principio alla base della costruzione di un albero di questo genere è molto semplice. Ipotizziamo di avere pagine di una data dimensione. Dopo aver partizionato lo spazio tramite un nodo. Possiamo andare a controllare quanti punti sono presenti in ogni partizione, se questa partizione contiene un numero minore o uguale al massimo numero di elementi in una pagina allora non è necessario procedere ricorsivamente, altrimenti si procede con una sotto-partizione. Questo approccio costruttivo è illustrato in @fig_09_pr_quadtree.

Una naturale generalizzazione dell'albero quaternario precedentemente illustrato si può trovare in alberi che per ogni dimensione dello spazio, lo dividono in due metà. Supponendo infatti che lo spazio sia di dimensione $d=3$, otterremo un *albero ottale* (octree), dove ogni nodo avrà 8 figli, ognuno dei quali rappresenta una delle 8 regioni in cui lo spazio tridimensionale viene diviso. Il problema consiste nel fatto che il numero di figli di un nodo cresce in maniera esponenziale con il numero delle dimensioni dello spazio. Mostriamo un esempio di octree in @fig_09_octree.

#figure(
  image("../images/ch09/octree.png", width: 70%),
  caption: "Esempio di costruzione di un point region octree",
)<fig_09_octree>

Il principale svantaggio legato a tecniche di questo genere è che spesso e volentieri ci troveremo ad avere *molto spazio inutilizzato*. Consideriamo l'esempio in @fig_09_pr_quadtree: possiamo notare che per separare in maniera efficiente i punti $C$ e $D$ si è reso necessario andare ad allocare due ulteriori pagine che però non contengono alcun punto. Questo problema viene ulteriormente amplificato nel caso di spazi con dimensioni maggiori di 2.

=== KDB - Tree
Per far fronte al problema della grande quantità di spazio inutilizzato andando ad applicare un partizionamento rigido come quello indotto da quadtree e octree, possiamo adottare una struttura più flessibile e bilanciata: il *KDB-Tree*. L'idea di base è la seguente:

- lo spazio viene suddiviso in maniera ricorsive lungo assi alternati
- ogni *nodo interno* contiene un insieme di regioni rettangolari che suddividono lo spazio in partizioni non sovrapposte
- ogni *regione* è associata ad un puntatore che va o ad un altro nodo interno o ad una *point page* che contiene i record

Il numero di regioni in ogni nodo è limitato dalla *capacità della pagina*. Un esempio di utilizzo di questa struttura si può vedere in @fig_09_kdb_tree.

#figure(
  image("../images/ch09/kdb_tree.png", width: 70%),
  caption: "Esempio di KDB-Tree dato un dataset",
)<fig_09_kdb_tree>

Oltre alla possibilità di scegliere di partizionare lungo un solo asse alla volta, cosa che nei quadtree e octree non è possibile, si noti che è anche possibile scegliere una soglia di partizionamento che non sia necessariamente il punto medio dell'asse.

== Alberi G - Partizionamento Non-Overlapping
Un'altra struttura dati molto utilizzata per la gestione di dati multi-dimensionali è data dai *G-Trees*. Si tratta di una struttura che combina il *partizionamento* dello spazio e dei *B+ Tree* in maniera originale: lo spazio è diviso in regioni non sovrapposte di dimensione variabile che vengono identificate tramite un codice. In seguito viene definito un ordinamento totale sui codici delle regioni, e vengono memorizzate in un B+ Tree.

=== Codifica delle Partizioni - Creazione del Partition Tree
Di seguito mostriamo come viene definito il codice di ogni regione nello spazio partizionato:

- la regione iniziale che contiene tutti i punti viene identificata tramite stringa vuota
- con il primo split lungo l'asse $X$, due partizioni sono prodotte ed identificate tramite i codici '0' e '1'. Ipotizziamo che entrambi gli attributi prendano valori in $[0, 100]$. Tutti i punti che hanno $X < 50$ finiranno nella partizione sinistra (codice '0'), mentre tutti i punti con $X >= 50$ finiranno nella partizione destra (codice '1').
- Quando una partizione contiene più punti di quanti ne possa contenere una pagina si procede con uno split sull'asse opposto (in questo caso $Y$) e nuovamente i punti vengono divisi in due partizioni, che vengono identificate tramite l'aggiunta di un ulteriore bit al codice della partizione padre.


In generale quando una partizione $R$ con codice `S` viene divisa, le sotto-partizioni con valori minori della metà dell'intervallo considerato avranno codice `S0`, mentre le altre avranno codice `S1`.
Un esempio di funzionamento di questo processo è illustrato in @fig_09_partition_tree.

L'albero costruito in @fig_09_partition_tree è detto *partition tree*, e servirà ad andare a costruire la possibile partizione in cui un nodo potrebbe essere presente in fase di ricerca.


#figure(
  image("../images/ch09/g_tree.png", width: 60%),
  caption: "Esempio di G-Tree dato un dataset",
)<fig_09_partition_tree>




Una volta stabiliti gli identificatori di ogni regione possiamo passare a costruire il B+ Tree che andrà a memorizzare i puntatori alle effettive regioni.
=== Creazione del G Tree
Una volta definito il *partition tree* possiamo procedere con la creazione del *G Tree*, che consiste semplicemente nel creare il B+ Tree associato alle regioni, basterà considerare gli encoding ottenuti con dello zero padding a destra e convertirli in decimale, nel caso dell'esempio in @fig_09_partition_tree avremo i corrispettivi binari dei numeri 0, 4, 5, 6, 8. Andando ad effettuare un inserimento per ogni elemento (partendo da quello la cui rappresentazione binaria ha valore più alto in questo esempio) otterremmo l'albero binario rappresentato in @fig_09_gtree_btree

#figure(
  image("../images/ch09/gbtree.png", width: 80%),
  caption: "B+ Tree associato agli encoding delle partizioni identificate",
)<fig_09_gtree_btree>

#remark[
  Dal momento che le codifiche delle partizioni e il partition tree non sono parte integrante del G Tree, è importante che qualsiasi cambiamento nei dati al seguito di accessi in scrittura a dati nel G-Tree si riflettano anche su questi componenti.
]

=== Ricerca di un Punto
Supponiamo che $M$ sia la massima lunghezza di un codice di partizione (in formato binario) all'interno del G-Tree. La ricerca di un punto di coordinate $(x,y)$ procede nella maniera seguente:

- ricerca all'interno del *partition tree* per un codice $S_P$ che contenga $P$ se presente
- ricerca del *G-Tree* dell codice di partizione $S_P$ per verificare che $P$ sia effettivamente nella partizione associata alle sue coordinate

Supponiamo per esempio di voler cercare $P = (30,60)$: andando a scorrere il partition tree troveremmo che il codice di partizione ad esso associato è $S_P = 011$, andando a scorrere il G-Tree scopriamo che questo codice di partizione è quello relativo al valore 6, presente nel nodo foglia $F_2$. Sarà a questo punto necessario controllare la pagina corrispondente per verificare la presenza del punto richiesto dalla query.

=== Ricerca di un Range Spaziale
Come sappiamo per la ricerca di punti in un range di valori, siamo interessati in tutti quei punti $P_i$ di coordinate $x_i, y_i$ tali che $x_1 <= x_i <= x_2$ e $y_1 <= y_i <= y_2$ che si trovano nella regione definita dalle query: $R = {(x_1, y_1), (x_2, y_2)}$. Per risolvere la query procediamo come segue:

- Cerchiamo la pagina $F_h$ che contiene il punto identificato dalle coordinate $(x_1, y_1)$
- Cerchiamo la pagina $F_k$ che contiene il punto identificato dalle coordinate $(x_2, y_2)$
- Per ogni nodo foglia tra $F_h$ e $F_k$ che sappiamo essere connessi tramite puntatori a livello delle foglie, vengono cercati gli elementi $S$ tali che la regione a cui fa riferimento $S$ sia sovrapposta o contenuta in $R$
- Se la regione è totalmente inclusa in $R$ allora tutti i punti soddisfano la query, in caso contrario sarà necessario verificare punto per punto l'aderenza alla query

#remark[
  Si noti come, per permettere lo svolgimento di query di questo genere è necessario che venga prevista una funzione del tipo _RegionOf(S)_ che dato in input il codice di una partizione, restituisca il vertice in basso a sinistra e quello in alto a destra della regione $R_S$.
]

#example-box("Ricerca di un range", [
  Supponiamo di voler cercare tutti i punti nella regione
  #math.equation(
    block: true,
    numbering: none,
    $
      R = {(35, 20), (45, 60)}
    $,
  )
  facendo riferimento al grafico in @fig_09_partition_tree. Utilizzando la codifica delle partizioni tramite numeri interi e il partition tree, il vertice inferiore è nella partizione 0, mentre quello superiore nella partizione 6. Ciò significa che esaminando il G tree dovremo analizzare le partizioni 0, 4, 5, 6, ossia tutte quelle comprese tra la 0 e la 6.

  Sappiamo che la partizione 0 corrisponde alla regione $R_0 = {(0,0), (50,50)}$. Questa partizione è sovrapposta ad $R$, dunque andrà recuperata la pagina associata e verificato che tutti i suoi punti ne facciano parte. Le partizioni 4 e 5 non sono sovrapposte, mentre la numero 6 lo è, portandoci dunque a dover esaminare ogni suo punto.
])

=== Inserimento di un Punto
Sia $M$ la massima lunghezza di un partition code nel G-Tree. L'inserimento di un punto $P$ con coordinate $(x,y)$ si svolge nella maniera seguente:

- cerchiamo nel G-Tree la foglia $F$ che dovrebbe contenere la partizione $R_P$ che dovrebbe andare a contenere $P$. Sia $S_P$ il codice di questa partizione.
- Se $R_P$ non è completa, possiamo inserire direttamente il punto $P$, altrimenti $R_P$ deve essere divisa in due sotto-partizioni $R_P_1, R_P_2$.
- I codici associati a queste partizioni sono rispettivamente $S_P_1 = S_P"0"$ e $S_P_2 = S_P"1"$. Nel caso in cui la lunghezza di questi codici sia maggiore di $M$ allora $M = M+1$ e le codifiche in intero di tutte le partizioni dovranno essere modificate di conseguenza.
- Tutti i punti di $R_P$ vengono divisi nelle due sotto-partizioni. La partizione di destinazione è determinata tramite il primo passo dell'algoritmo di ricerca.
- L'elemento $S_P$ con il relativo puntatore alla pagina di $R_P$ viene sostituito con due nuovi elementi $(S_P_1, "ref"(R_P_1))$ e $(S_P_2, "ref"(R_P_2))$. Nel caso di overflow nel nodo foglia, si procede con la suddivisione del nodo come in un normale B+ Tree.

Facciamo sempre riferimento al solito esempio in @fig_09_partition_tree. Immaginiamo di volere aggiungere il punto $P_1 = (70, 65)$. In questo caso la sua regione di destinazione è quella identificata dal codice 8 con codice '1'. Dal momento che la pagina ha ancora elementi liberi (1 < 2) possiamo procedere con l'inserimento diretto del punto.

Immaginiamo ora di volere inserire il punto $P_2 = (8, 65)$. La sua regione destinazione dovrebbe essere la numero 4 con codice '0100'. La pagina associata però non ha sufficiente spazio. Viene dunque divisa in due sotto-partizioni causando una modifica delle codifiche e del B+ Tree ad esse associato. @fig_09_gtree_insert mostra il risultato finale dopo l'inserimento di entrambi i punti.

#figure(
  image("../images/ch09/gtree_insert.png", width: 90%),
  caption: "Esempio di G-Tree dopo l'inserimento di due punti P1 e P2",
)<fig_09_gtree_insert>

#pagebreak()

=== Cancellazione di un Punto
Di seguito mostriamo il procedimento di cancellazione di un punto $P = (x,y)$ dal G-Tree:

+ sia $F$ la foglia associata alla partizione $R_P$ che contiene il punto $P$ e $S_P$ il codice di questa partizione. Sia $S'$ il codice della partizione $R'$ ottenuta dal 'padre' di $R_P$ tramite uno split. Possiamo notare che $R'$ ha codice esattamente uguale a $S_P$ ad eccezione dell'ultimo bit.

+ eliminiamo il punto $P$ dalla pagina associata ad $R_P$. Abbiamo ora due possibilità:

  - Se la 'sorella' $R'$ è già stata splittata, non è possibile applicare fusioni. Controlliamo che $R_P$ non sia diventata vuota, in tal caso eliminiamo l'elemento $S_P$ dalla foglia $F$. Se $R_P$ è vuota andiamo a cancellare l'elemento $S_P$ dalla foglia $F$.
  - Se la sorella $R'$ non è stata divisa, allora dobbiamo controllare la somma del numero di elementi di $R$ e $R'$. Se questa somma è maggiore della capacità di una pagina, allora l'operazione termina, altrimenti possiamo applicare una *fusione* delle due partizioni: $S_p, S'$ vengono eliminate dall'albero e viene generate una nuova stringa $S''$ ottenuta cancellando l'ultimo bit da $S_P$.

Applicando un'operazione di cancellazione al G-Tree in @fig_09_gtree_insert per $P_1, P_2$ torniamo alla situazione mostrata in @fig_09_partition_tree e @fig_09_gtree_btree.

== Alberi *$"R"^*$* - Partizionamento con Overlapping
Nell'ultima sezione di questo capitolo andiamo a illustrare una tecnica per gestire l'ultima opzione di partizionamento mostrata all'inizio del capitolo, ossia il *partizionamento* che *ammette overlapping* tra le regioni. La struttura dati utilizzata per questo scopo è quella degli *alberi $"R"^*$* ($"R"^*$-Trees).

=== Struttura degli Alberi *$"R"^*$*
Un albero $"R"^*$ è una variante di un albero R. Si tratta di una struttura dinamica *perfettamente bilanciata* (similmente ai B+ Tree). Per semplicità consideriamo di nuovo il caso bidimensionale.

Dal momento che in questo tipo di organizzazione ha a che fare con regioni dello spazio, ogni elemento dell'albero andrà a contenere le informazioni relative ad un *minimum bounding rectangle*, ossia il rettangolo di dimensione minima che contiene i punti in una regione. Ogni rettangolo sarà identificabile tramite le coordinate del vertice in basso a sinistra e di quello in alto a destra.

Dal punto di vista pratico, i nodi più in alto dell'albero conterranno degli iper-rettangoli che al loro interno contengono regioni sempre più specifiche, fino ad arrivare ai nodi foglia che conterranno i minimum bounding rectangle dei singoli punti. Per rendere questa notazione più formale diremo che i *nodi foglia* saranno della forma $R_i, O_i$ dove $R_i$ rappresenta le coordinate che identificano il rettangolo, mentre $O_i$ è un puntatore effettivo ai dati. I *nodi interni* invece saranno della forma $(R_i, p_i)$ dove $p_i$ è un riferimento alla radice di un sotto-albero, ed $R_i$ contiene le informazioni per identificare il MBR che contiene tutti i rettangoli dei nodi figli. Similmente ai B+ Tree, per mantenere il *bilanciamento* ogni nodo avrà un numero minimo e un numero massimo di elementi.

Per meglio comprendere come i vari minimum bounding bounding rectangle dei livelli superiori contengano quelli dei livelli inferiori possiamo fare riferimento a @fig_generalized_tree_search, in riferimento alla quale mostriamo il corrispondente $"R"^*$-Tree in @fig_09_rstar_tree.

#figure(
  image("../images/ch09/r*tree.png", width: 70%),
  caption: "Esempio di R*-Tree dato un dataset",
)<fig_09_rstar_tree>

Dal momento che è necessario definire il numero minimo e massimo di elementi per ogni nodo, una pratica comune è che il minimo $m = 0.4 dot M$. Un $"R"^*$-Tree soddisfa le proprietà seguenti:

- il nodo radice ha almeno due figli, a meno che non sia l'unico nodo dell'albero
- ogni nodo ha un numero di elementi compreso tra $m$ e $M$ a meno che non la radice
- tutti i nodi foglia sono allo stesso livello

Ci sono delle sostanziali differenze tra gli alberi $"R"^*$ e gli alberi B+, di seguito le illustriamo:

- gli elementi dei nodi di un albero $"R"^*$ *non sono ordinati* in alcun modo
- le regioni associate a diversi elementi di un nodo *possono sovrapporsi* in un B+ tree, questo invece è esattamente il requisito per un albero $"R"^*$


=== Ricerca di Regioni sovrapposte
L'operazione principale che si può svolgere su un albero di questo tipo è la ricerca di tutte le regioni che sono sovrapposte ad una data regione specificata nella query $R$. La radice viene visitata in maniera da cercare elementi $(R_i, p_i)$ tali che $R_i$ sia sovrapposta a $R$. Per ogni elemento $(R_i, p_i)$ che soddisfa questo requisito si procede ricorsivamente nel sotto-albero puntato da $p_i$. Quando raggiungiamo un nodo foglia, le regioni $R_i$ nel risultato della query sono quelle che sono sovrapposte a $R$.

=== Inserimento nell'Albero
Sia $S$ una nuova porzione di dati da voler inserire nell'albero. L'operazione è molto simile all'inserimento di una chiave all'interno di un B+ Tree. La differenza sostanziale consiste nel fatto che in un B+ Tree la posizione in cui aggiungere la nuova chiave è univocamente determinata dall'ordinamento.

In un albero $"R"^*$, dal momento che regioni in diversi nodi interni allo stesso livello potrebbero sovrapporsi, la nuova regione $S$ potrebbe sovrapporsi con più di questi nodi e potrebbe dunque essere inserita in più foglie con diversi possibili nodi interni come padri.

La scelta di quale regione considerare può essere effettuata andando a considerare il *grado di sovrapposizione* con $S$. Per esempio si potrebbe scegliere la regione che vedrebbe il minore cambiamento di area del bounding box per andare a contenere anche $S$. Dopo aver scelto in quale nodo foglia inserire $S$, si procede con il suo inserimento, nel caso in cui non siano presenti overflow viene ricalcolata la regione e propagato il nuovo valore al nodo padre, altrimenti consideriamo due casi:

- *forced reinsert*: se abbiamo a che fare con il primo overflow da un nodo foglia, non viene diviso a metà, piuttosto $p$ degli $M+1$ ingressi vengono rimossi dal nodo e reinseriti nell'albero. A livello pratico un buon valore di $p$ si aggira attorno al 30% del valore di $M$. Questo approccio potrebbe permettere di evitare di dover dividere il nodo, andando a ridurre la sovrapposizione tra le regioni.
- *split del nodo*: dopo il primo overflow, gli $M+1$ elementi sono divisi tra due nodi e due nuovi elementi sono inseriti nel nodo padre, gli effetti vengono poi propagati in alto nell'albero. Nel momento in cui dovessimo avere più possibilità per dividere gli elementi del nodo scegliamo il criterio il criterio che minimizza il *perimetro totale* delle regioni ottenute.

#example-box("Inserimento di nuovi dati", [
  Consideriamo il solito partizionamento di @fig_generalized_tree_search che riportiamo di seguito per comodità e assumiamo di voler aggiungere una nuova regione $S$ rappresentata nell'immagina a finaco

  #align(center)[
    #grid(
      columns: (40%, 40%),
      image("../images/ch09/generalized_treesearch.png", width: 90%),
      image("../images/ch09/dataregion_insertion.png", width: 90%),
    )
  ]

  Il processo di inserimento inizia con il nodo radice presentato nella figura seguente:

  #align(center)[
    #image("../images/ch09/preinsertion_root.png", width: 50%)
  ]
  Le regioni candidate alla memorizzazione di $S$ sono $R_(23)$ e $R_(21)$. Dal momento che $R_(21)$ richiede un aumento minore dell'area del bounding box per contenere $S$, scegliamo questa regione per l'inserimento. Seguendo il puntatore $p_(21)$ nell'immagine precedente andremo a considerare il nodo foglia a sinistra; andando ad inserire il nuovo elemento otteniamo un *overflow*, dal momento che è il primo possiamo procedere con un *forced reinsert*. Supponiamo di provare a reinserire la data region $R_1$. Ciò che avverrebbe in questo caso è che la regione $R_1$ verrebbe nuovamente inserita nella stessa sovra-regione $R_21$. andando a causare un *secondo overflow*.

  A questo punto andrà a verificarsi una *suddivisione* della regione. Supponiamo di aver diviso le data region in ${R_1, S}$ e ${R_2, R_3}$. Siano rispettivamente $R_24$ ed $R_25$ i minimum bounding rectangle associati a queste due nuove regioni. Andremo ad aggiornare il nodo padre. A livello di nodo *radice* _non ha alcun senso praticare reinserimento_ procediamo dunque con un nuovo *split* della radice ipotizzando che verrà divisa in due nuove regioni $R_(26)$ e $R_(27)$ che conterranno rispettivamente ${R_24, R_25}$ e ${R_22, R_23}$. Di seguito mostriamo la situazione finale:

  #figure(
    grid(
      columns: (35%, 65%),
      align: horizon,
      image("../images/ch09/dataregions_after_insert.png", width: 100%),
      image("../images/ch09/r*tree_afterinsert.png", width: 100%),
    ),
  )

])
