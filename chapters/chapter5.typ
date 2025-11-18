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

= Graph Databases

Nel corso di questo capitolo andremo ad affrontare basi di dati organizzate come *grafo*. Nella prima parte andremo a vedere i concetti fondamentali, per poi passare a vedere una delle implementazioni più diffuse: *Neo4j*.

== Teoria dei Grafi
In questa sezione andiamo a porre le basi teoriche per comprendere il concetto al fondamento di questa categoria di base di dati: i *grafi*, di cui andiamo a dare una definizione.

#definition(title: "Grafo")[
  Un grafo $G$ è una struttura costituita da un insieme di *vertici* e di *archi* $G = (V, E)$, dove:

  - ogni _vertice_ $v #sym.in V$ rappresenta un'entità o un oggetto;
  - ogni _arco_  $e #sym.in E$ rappresenta una relazione o connessione tra due vertici.
  - Gli archi possono essere *diretti* o indiretti, a seconda che la relazione abbia una direzione specifica o meno.
]<def:graph>

Un grafo è detto diretto se tutti i suoi archi hanno una direzione associata, al contrario, se nessun arco ha direzione, il grafo si dice indiretto. @fig:05_indirected_vs_directed mostra un esempio di grafo diretto e indiretto.

#figure(
  image("../images/ch05/05_indirected_vs_directed.png", width: 75%),
  caption: "Esempio di grafo diretto (a sinistra) e indiretto (a destra).",
)<fig:05_indirected_vs_directed>

Un grafo si dice un *multigrafo* se ha una coppia di nodi che è connessa tramite più di un arco. Questa caratteristica è utile per rappresentare relazioni complesse tra entità, come ad esempio in una rete di trasporti dove più linee possono collegare due stazioni. @fig:05_multigraph mostra un esempio di multigrafo.

#figure(
  image("../images/ch05/05_multigraph.png", width: 35%),
  caption: [Esempio di multigrafo con più archi tra alcuni nodi. $e_3, e_4$ sono archi multipli tra i nodi $v_2$ e $v_3$.],
)<fig:05_multigraph>

Possiamo avere anche degli *ipergrafi*, in cui un arco può connettere più di due vertici. Tuttavia, per i nostri scopi, ci concentreremo su grafi più semplici.

#definition(title: "Adiacenza tra Nodi")[
  Due vertici $v_1, v_2$ sono detti *adiacenti*, se sono 'vicini', ovvero se esiste un arco che li connette in maniera diretta.
]<def:adjacency>

#definition(title: "Incidenza")[
  Un arco $e$ è detto *incidente su un vertice* se è connesso a quel vertice. Nel caso di grafi diretti distinguiamo due casi:

  - *positivamente* incidente se l'arco parte dal vertice,
  - *negativamente* incidente se l'arco arriva al vertice.
]<def:incidence>

Vedremo in seguito come i concetti introdotti da @def:adjacency e @def:incidence siano fondamentali per comprendere come andare a memorizzare in maniera efficiente un grafo all'interno della memoria.

=== Navigazione in un Grafo
La navigazione di un grafo è nota anche con il nome di *graph traversal* e sostanzialmente è alla base di tutte le operazioni che possiamo effettuare su un grafo.

Un *path* (o percorso) in un grafo è una sequenza di vertici e archi che collega un vertice di partenza a un vertice di arrivo.

#example-box("Path in un Grafo")[
  Consideriamo il grafo in @fig:05_graph_path. Possiamo notare che esiste un path tra il nodo 'Alice' e il nodo 'Marcus' che passa per 'Bob'. Il fatto che possiamo giungere da Alice a Marcus, passando per Bob, implica che Alice e Marcus sono 'conoscenti di conoscenti'.
  #figure(
    image("../images/ch05/05_graph_traversal.png", width: 70%),
    caption: "Rappresentazione delle relazione 'conoscenti di conoscenti' tramite un grafo",
  )<fig:05_graph_path>
]

In riferimento all'esempio precedente, possiamo notare come alla definizione di grafo introdotta da @def:graph manchi un concetto fondamentale nel contesto delle basi di dati: il dare un nome agli archi, che rappresentano relazioni trai nodi.

Quando andiamo a visitare un grafo, possiamo porci una domanda fondamentale: "*In che ordine dovremmo visitare i nodi?*". Esistono diversa alternative per rispondere a questa domanda, le più comuni sono:

- *Depth-First Search (DFS)*: questa strategia esplora il più lontano possibile lungo ogni ramo prima di tornare indietro. In pratica, si visita un nodo, poi si visita uno dei suoi vicini, e così via, fino a quando non si raggiunge un nodo senza vicini non visitati. A quel punto, si torna indietro e si esplorano gli altri vicini.
- *Breadth-First Search (BFS)*: questa strategia esplora tutti i vicini di un nodo prima di passare ai nodi di livello successivo. In pratica, si visita un nodo, poi si visitano tutti i suoi vicini, poi i vicini dei vicini, e così via.
- *Altri algoritmi specializzati*: esistono molti altri algoritmi di navigazione dei grafi, come Dijkstra per il calcolo del percorso più breve, $"A"^#sym.star$, Dijkstra, Bellman-Ford, e molti altri, ciascuno con le proprie caratteristiche e casi d'uso specifici.

=== Problemi sui Grafi
I grafi sono utilizzati per modellare una vasta gamma di problemi nel mondo reale. Sono stati dunque sviluppati numerosi problemi classici sui grafi, tra cui:

- *Graph Traversal*: anche se già menzionato in precedenza è importante sottolineare che la navigazione di un grafo è un problema fondamentale, con molte varianti e applicazioni. Consiste nella visita di _tutti i nodi_ al suo interno
- *Eulerian Path*: trovare un percorso che attraversa tutti i nodi passando per ogni arco esattamente una volta.
- *Eulerian Cycle*: iniziando da un path euleriano, vorremmo iniziare e terminare nello stesso nodo.
- *Hamiltonian Path*: trovare un percorso che visita ogni nodo esattamente una volta.
- *Hamiltonian Cycle*: in maniera simile a prima, vorremmo un path hamiltoniano che inizi e termini nello stesso nodo.
- *Minimum Spanning Tree*: trovare un albero che oltre a collegare tutti i nodi, minimizza il costo totale degli archi utilizzati.

== Basi di Dati a Grafo
L'idea alla base delle basi di dati a grafo è quella che sia estremamente importante rappresentare i *collegamenti* trai dati memorizzati. In una base di dati relazionale, le relazioni tra entità sono rappresentate tramite chiavi esterne, che per quanto funzionali, non sono così intuitive, l'utilizzo di un grafo è quanto di più naturale per rappresentare queste relazioni. Di seguito Qualche esempio in cui basi di dati di questo tipo sono particolarmente utili:

- *Social Networks*: le relazioni tra utenti, amici, follower, ecc. sono naturalmente rappresentate come grafi.
- *Recommendation Systems*: le connessioni tra utenti e prodotti possono essere modellate come graf
- *Web Semantico*: le relazioni tra pagine web, link, e contenuti possono essere rappresentate come grafi.
- *Sistemi Informativi Geografici*: le reti stradali, i percorsi di trasporto, e le connessioni geografiche sono spesso modellate come grafi.
- *Bioinformatica*: le reti di interazioni tra proteine, geni, e altre entità biologiche sono spesso rappresentate come grafi.

@fig:05_graph_db_example mostra un esempio di come una base di dati a grafo possa essere utilizzata per rappresentare le relazioni tra utenti in un social network e in un sistema geospaziale.

#figure(
  image("../images/ch05/05:db_examples.png", width: 100%),
  caption: "Esempi di basi di dati a grafo in un social network (a sinistra) e in un sistema geospaziale (a destra).",
)<fig:05_graph_db_example>

=== Modello dei Dati
Le basi di dati a grafo utilizzano un modello di dati chiamato *Property Graph Model*, che andiamo di seguito a definire.

#definition(title: "Property Graph Model")[
  Un *property graph* è un *multigrafo diretto* che memorizza informazioni (proprietà) sia sui nodi che sugli archi. Una *proprietà* è una coppia chiave-valore (es. `Name: Alice`). A volte è possibile avere proprietà _multi-valore_: una chiave e un insieme di elementi associati (es. `Hobbies: {Reading, Hiking, Coding}`).

  Per ogni nodo e arco viene definita una proprietà di default chiamata *`Id`* che identifica univocamente l'elemento all'interno del grafo.
]<def:property_graph>

In @fig:05_property_graph_example è mostrato un esempio di property graph che rappresenta una piccola rete sociale.

#figure(
  image("../images/ch05/05_graph_data_model.png", width: 60%),
  caption: "Esempio di Property Graph che rappresenta una rete sociale.",
)<fig:05_property_graph_example>

In generale non viene imposto alcun vincolo sul tipo di dati, che possono essere coppie chiave-valore di *tipo arbitrario*. Ad ogni modo è buona pratica utilizzare tipaggio per dare valore semantico ai valori memorizzati:

- Per i _vertici_ viene utilizzata una proprietà di _default_, chiamata `Type`
- Per gli _archi_ viene utilizzata una proprietà di _default_, chiamata `Label`, opzionalmente è anche possibile andare a definire quali edge labels possono connettere certi nodi in base al tipe che viene specificato per questi

Possiamo notare che l'utilizzo delle proprietà `Type` e `Label` corrisponde circa a dire che un certo nodo o una certa relazione tra nodi fanno parte di una certa *classe*. In questo modo, l'esempio in @fig:05_property_graph_example può essere riformulato reintroducendo il valore semantico delle relazioni nel grafo come viene fatto in @fig:05_graph_with_types.

#figure(
  image("../images/ch05/05_graph_with_types.png", width: 70%),
  caption: "Esempio di Property Graph con tipi e label che rappresenta una rete sociale.",
)<fig:05_graph_with_types>

Non è obbligatorio, ma in generale possiamo aspettarci che nodi e archi che fanno parte di una stessa 'classe' condividano le stesse proprietà. Introduciamo un ultimo particolare vincolo, che riguarda la presenza di *multi-edge*, questi non possono connettere gli stessi nodi con la stessa "Label" di relazione. Vogliamo evitare questa situazione per evitare di avere *ambiguità* nell'interpretazione del grafo. @fig:05_multi_edge_with_different_labels mostra un esempio di multi-edge non ammesso.

#figure(
  image("../images/ch05/05_multiedge_invalid.png", width: 70%),
  caption: "Esempio di multi-edge non ammesso dal momento che ha la stessa label di un altro arco già presente per collegare gli stessi nodi.",
)<fig:05_multi_edge_with_different_labels>


=== Memorizzazione di un Grafo
Questa sezione è dedicata a illustrare come viene salvata in memoria la struttura del grafo. Se per quanto riguarda i vari nodi, potrebbe risultare intuitivo come andare a memorizzarli, la questione sia complica quando andiamo a cercare di rappresentare gli *archi*.

Abbiamo infatti bisogni di raggiungere un buon *tradeoff* tra *memorizzazione rapida* e *possibilità di utilizzare di dati in modo efficiente* (es. graph traversal).

==== Strategia Naive
Una possibile strategia molto semplice è quella di memorizzare l'insieme dei nodi $V$ e l'insieme degli archi $E$ come liste separate. Ogni arco conterrà un riferimento ai nodi che connette. Di seguito andiamo ad elencare i pro e contro di questa strategia:

- L'*inserimento* è molto rapido, dal momento che basta aggiungere un nuovo nodo o un nuovo arco alla rispettiva lista, l'unica cosa di cui abbiamo bisogno è un puntatore alla prossima posizione in cui andiamo a scrivere #emoji.checkmark.box
- La determinazione delle *adiacenze* è particolarmente inefficiente, dal momento che dobbiamo scorrere l'intera lista degli archi per trovar quelli di interesse #emoji.crossmark
- La gestione delle operazioni di *cancellazione* è particolarmente inefficiente, dal momento che dobbiamo scorrere l'intera lista di interesse, cancellare il dato e ricompattare il tutto #emoji.crossmark

==== Matrice di Adiacenza
Una possibile strategia possibilmente più efficace è quella di utilizzare una *matrice di adiacenza*. In questo caso andremo a creare una matrice quadrata di dimensione $|V| #sym.times |V|$. Ogni riga e colonna andrà a rappresentare i vertici $v_1, ..., v_n$.

Nel caso di grafi senza archi, la matrice di adiacenza conterrà unicamente zeri. Nel caso in cui siano presenti degli archi abbiamo due possibilità in base al tipo di grafo:

- Per *grafi non diretti a-ciclici*: se esiste un arco tra il nodo $v_i$ e $v_j$, alllora andremo a scrivere uno nella cella $(i, j)$ e nella cella $(j, i)$ della matrice di adiacenza.
- Per *grafi non diretti con cicli*: nel caso di un loop tra il $v_i$ e sé stesso, andremo a scrivere 2 nella cella $(i, i)$ della matrice di adiacenza.
- Per *grafi diretti a-ciclici*: se esiste un arco dal nodo $v_i$ al nodo $v_j$, allora andremo a scrivere uno nella cella $(i, j)$ della matrice di adiacenza.
- Per *grafi diretti con cicli*: nel caso di un loop tra il $v_i$ e sé stesso, andremo a scrivere 1 nella cella $(i, i)$ della matrice di adiacenza.

#remark[
  Nel caso di grafi non diretti la matrice di adiacenza sarà sempre simmetrica, mentre non lo sarà necessariamente nel caso di grafi diretti.
]

#remark[
  Il motivo per cui in un grafo non diretto con ciclo andiamo a scrivere due nella cella $(i,i)$ sta nel fatto che in grafi non diretti ogni arco è contato in maniera simmetrica, dunque un loop viene contato due volte. Ciò non avviene nel caso di grafi diretti.
]

Andiamo ora a mostrare cosa succede nel caso di *multigrafi non diretti*:

- Nel caso di multigrafo diretto *a-ciclico*: se esistono $k$ archi tra il nodo $v_i$ e $v_j$, allora andremo a scrivere $k$ nella cella $(i, j)$ e nella cella $(j, i)$ della matrice di adiacenza.
- Nel caso di multigrafo diretto *con cicli*: nel caso in cui si verifichino $k$ loops del tipo $v_i, v_i$, andremo a scrivere $2 #sym.dot k$ nella cella $(i, i)$ della matrice di adiacenza.


Nel caso in cui di *multigrafi diretti* avremo la seguente situazione:

- Nel caso di multigrafo diretto *a-ciclico*: se esistono $k$ archi dal nodo $v_i$ al nodo $v_j$, allora andremo a scrivere $k$ nella cella $(i, j)$ della matrice di adiacenza.
- Nel caso di multigrafo diretto *con cicli*: nel caso in cui si verifichino $k$ loops del tipo $v_i, v_i$, andremo a scrivere $k$ nella cella $(i, i)$ della matrice di adiacenza

#figure(
  image("../images/ch05/05_graph2adjacency.png", width: 90%),
  caption: "Esempio di multigrafo non diretto con cicli (a sinistra) e la sua matrice di adiacenza (a destra).",
)<fig:graph2ajdacency>

Di seguito andiamo ad elencare vantaggi e svantaggi di questo approccio:

- La determinazione delle *adiacenze* è molto rapida, dal momento che basta accedere alla cella di interesse della matrice #emoji.checkmark.box
- È estremamente facile *inserire* un nuovo arco, dal momento che basta incrementare il valore nella cella di interesse #emoji.checkmark.box
- È particolarmente *costoso* dal punto di vista della memoria, dal momento che dobbiamo memorizzare una matrice di dimensione $|V| #sym.times |V|$, specialmente quando i nodi sono molti la dimensione della matrice potrebbe diventare di difficile gestione #emoji.crossmark
- Spesso e volentieri i grafi sono *sparsi*, ovvero hanno pochi archi rispetto al numero di nodi, in questo caso la matrice di adiacenza conterrà molti zeri, andando così a sprecare memoria #emoji.crossmark
- Le operazioni di *inserimento di nuovi nodi* sono particolarmente costose, dal momento che dobbiamo aumentare la dimensionalità della matrice #emoji.crossmark
- Non è possibile memorizzare iper-grafi, dal momento che la matrice di adiacenza può rappresentare solamente archi che connettono due nodi #emoji.crossmark
- Determinare *tutte le adiacenze* di un nodo è particolarmente inefficiente, dal momento che dobbiamo scorrere l'intera riga o colonna della matrice di interesse, che nel caso di grafi con molti nodi potrebbe essere un'operazione lenta #emoji.crossmark

==== Matrice di Incidenza
Un possibile alternativa alla matrice di adiacenza è la *matrice di incidenza*. In questo caso andremo a creare una matrice di dimensione $|V| #sym.times |E|$. Ogni riga andrà a rappresentare i vertici $v_1, ..., v_n$, mentre ogni colonna andrà a rappresentare gli archi $e_1, ..., e_m$.

I valori nelle celle della matrice di incidenza saranno assegnati in maniera simile a quanto visto per la matrice di adiacenza, con la differenza che dovremo tenere conto della positività e della negatività delle incidenze.

@fig:05_incidence_matrix_example_undirected e @fig:05_incidence_matrix_example_directed mostrano le differenze nella matrice di adiacenza nel caso di grafi diretti e indiretti.

#figure(
  image("../images/ch05/05_ndgraph_to_incidence.png", width: 90%),
  caption: "Esempio di multigrafo diretto con cicli (a sinistra) e la sua matrice di incidenza (a destra).",
)<fig:05_incidence_matrix_example_undirected>

#figure(
  image("../images/ch05/05_dgraph_to_incidence.png", width: 90%),
  caption: "Esempio di multigrafo diretto con cicli (a sinistra) e la sua matrice di incidenza (a destra).",
)<fig:05_incidence_matrix_example_directed>

Di seguito andiamo a riportare vantaggi e svantaggi di questo approccio:

- Non avremo colonne di soli zeri, dal momento che queste rappresentano gli archi e usiamo colonne solo per gli archi esistenti #emoji.checkmark.box
- È possibile memorizzare iper-archi #emoji.checkmark.box
- Dal punto di vista dello *storage* si tratta di un approccio particolarmente *intensivo* ($n #sym.times m$) #emoji.crossmark
- Nel caso di grafi con molti nodi, le *colonne* avranno comunque *molti* *zeri*, dal momento che una colonna rappresenta un arco
- Determinare le *adiacenze* per un vertice richiede il lookup di tutta la riga corrispondente #emoji.crossmark
- L'*inserimento* di un nuovo nodo richiede l'aggiunta di una nuova riga alla matrice, risultando *costoso* #emoji.crossmark

Invece di utilizzare *matrici* per rappresentare i grafi, un'alternativa più efficiente è quella di utilizzare delle *liste di adiacenza*, questo permette di risparmiare memoria fondamentale e di velocizzare l'esecuzione di operazioni comuni sui grafi.

==== Liste di Adiacenza
L'idea alla base di una lista di adiacenza è quella di memorizzare per ogni nodo, una lista di nodi adiacenti. In questo modo, possiamo rappresentare un grafo come un array di liste. @fig:05_adj_list mostra come questo approccio possa essere implementato nel caso di un grafo indiretto a sinistra e di uno diretto a destra.




#figure(
  image("../images/ch05/05_adj_list.png", width: 90%),
  caption: "Esempio di rappresentazione di un grafo indiretto (a sinistra) e diretto (a destra) tramite liste di adiacenza.",
)<fig:05_adj_list>

Di seguito andiamo ad elencarne vantaggi e svantaggi:


- Effettuare un *lookup* di tutti i vertici adiacenti a un nodo è molto *efficiente*, dal momento che basta accedere alla lista corrispondente #emoji.checkmark.box
- Vengono memorizzato soltanto le informazioni rilevanti, non abbiamo *overhead* di memoria #emoji.checkmark.box
- L'*inserimento* di un nuovo nodo è *efficiente*, dal momento che basta aggiungere una nuova lista all'array #emoji.checkmark.box
- L'*inserimento* di un nuovo arco è *efficiente*, dal momento che basta aggiungere il nodo di destinazione alla lista del nodo/i di partenza/arrivo #emoji.checkmark.box
- È possibile memorizzare iper-archi #emoji.checkmark.box
- Determinare l'esistenza di un *arco specifico* può essere costoso, dal momento che potrebbe essere necessario scorrere l'intera lista di adiacenza #emoji.crossmark

#remark[Questa struttura per quanto efficiente non consente ancora di andare a memorizzare le proprietà associate a nodi ed archi, ma non si tratta di una operazione complicata, basta infatti memorizzare le *proprietà di un nodo* possiamo memorizzarle nel punto di *partenza della lista*, mentre le *proprietà di un arco* possono essere memorizzate nel *nodo di destinazione* all'interno della lista di adiacenza.]



#figure(
  image("../images/ch05/05_incidence_list.png", width: 70%),
  caption: "Esempio di rappresentazione di un grafo indiretto (a sinistra) e diretto (a destra) tramite liste di incidenza.",
)<fig:05_incidence_list>

==== Liste di Incidenza
Un'ulteriore possibile strategia per memorizzare un grafo è quella di utilizzare delle *liste di incidenza*. In questo caso, per ogni nodo andremo a memorizzare una *lista di archi* che sono incidenti su quel nodo. @fig:05_incidence_list mostra come questo approccio possa essere implementato nel caso di un grafo indiretto a sinistra e di uno diretto a destra.

#remark[
  Nel caso in cui volessimo andare a memorizzare degli *iper-grafi* questo sarebbe possibile, basterebbe andare ad aggiungere alla lista di incidenza relativa all'iper-arco tutti i nodi che questo coinvolge.
]

=== Graph Database Management Systems & API
Il focus di questa sezione è quello di andare ad illustrare come possiamo *accedere* ai dati memorizzati in un graph database. In realtà abbiamo diversi sistemi per farlo. Di seguito andiamo a mostrarne alcuni ognuno con le sue caratterisitiche.

==== TinkerPop
Si tratta di un framework open-source per la gestione di grafi che fornisce un API standardizzata per interagire con un graph db.

```Gremlin
Graph g = TinkerGraph.open();
Vertex alice = g.addVertex("name", "Alice");
alice.property("age", 34);
Vertex bob = g.addVertex("name", "Bob");
alice.addEdge("knows", bob, "since", 2020);
```

Di seguito andiamo a vedere un semplice codice per effettuare traversal del grafo creato tramite _method chaining_:

```Gremlin
g.traversal().V()   // prendiamo la lista dei vertici
  .has("name", "Alice") // filtriamo per il vertice con nome "Alice"
  .out("knows") // andiamo agli archi in uscita con label "knows"
  .values("name");  // prendiamo i nomi dei vertici raggiunti
```

==== Cypher
Un alternativa all'approccio di TinkerPop è quello di utilizzare un linguaggio di query tramite il quale andare a *descrivere pattern* riguardo *nodi* o *paths*. Il modo in cui possiamo definire questi patter avviene tramite l'utilizzo del linguaggio *Cypher*. Di seguito andiamo a vederne alcuni elementi sintattici:

- *`START`*: viene utilizzato per specificare i _nodi_ di partenza per una query
- *`MATCH`*: viene utilizzato per la specifica dei _pattern_ da ricercare
- *`WHERE`*: viene utilizzato per specificare delle _condizioni_ sui _nodi_ o sugli _archi_
- *`RETURN`*: viene utilizzato per specificare quali dati vogliamo vengano restituiti dalla query

In riferimento al grafo giocattolo costruito nell'esempio di prima possiamo costruire una query come quella descritta di seguito per trovare tutti i nodi adiacenti ad 'Alice':

```Cypher
START alice = (people_idx, name, "Alice")   // selezioniamo il nodo di partenza
MATCH (alice)-[:knows]->(aperson) // definiamo il pattern da cercare
return (aperson)
```

Quello che viene fatto nella query di sopra è:

- Selezionare il nodo di partenza 'Alice' tramite l'uso dell'indice `people_idx`
- Definire il pattern da cercare, ovvero tutti i nodi connessi ad 'Alice' tramite un arco con label 'knows'
- Restituire i nodi trovati.

#remark[
  Si noti come, dal momento che non sono stati specificati vincoli sui nodi o sugli archi, la query restituirà tutti i nodi adiacenti ad 'Alice' tramite un arco con label 'knows', non necessariamente nodi con il suo stesso tipo (es. `Person`).
]

#pagebreak()
== Neo4j
Al contrario di moltissime altre tecnologie per la gestione dei dati, Neo4j è un *Graph Database nativo*, ovvero è stato progettato fin dall'inizio per memorizzare e gestire dati in forma di grafo.

Anche un database relazionale può essere visto come una struttura a grafo, ma in questo caso i grafi sono *derivati* dalle tabelle e dalle relazioni tra esse. Questo comporta che le operazioni su database relazionali possano diventare estremamente complesse e inefficienti quando si tratta di navigare attraverso molteplici relazioni.

=== Property Graph Model
Questa sezione va velocemente a riassumere i concetti fondamentali alla base di un qualsiasi database basato su un grafo, ovvero il _property graph model_. Di seguito andiamo a rielencare i concetti principali:

- *Nodi*: rappresentano gli oggetti (o entità) del grafo, ogni nodo può avere una *label* (o più di una) che ne definisce il tipo (es. `Person`, `Movie`, ecc.)
- *Relazioni*: rappresentano le connessioni (archi) tra i nodi, ogni relazione ha una *direzione* e una *label* che ne definisce il tipo (es. `KNOWS`, `ACTED_IN`, ecc.)
- *Proprietà*: sia i nodi che le relazioni possono avere proprietà, che sono coppie chiave-valore che memorizzano informazioni aggiuntive (es. `name: "Alice"`, `since: 2020`, ecc.)

L'immagine che segue mostra un esempio di un property graph model che contiene molteplici relazioni tra nodi, molte proprietà e tipi di nodi e relazioni diversi:

#align(center)[
  #image("../images/ch05/05_neo4j_propgraph.png", width: 65%)
]

L'idea alla base di Neo4j è quella di fornire uno strumento il più intuitivo e vicino possibile a ciò che un utente si aspetta quando pensa a un grafo.

=== Graph Querying: Qualche Esempio
Dato un grafo abbiamo bisogno di un modo per poter interrogare i dati in esso contenuti. Neo4j fornisce un linguaggio di query chiamato *Cypher*, che è stato progettato specificamente per lavorare con grafi. Si tratta di un linguaggio *dichiarativo* che pone alla sua base il concetto di *pattern matching* sui grafi, in maniera simile a quello che facciamo con le _espressioni regolari_ sui testi. @fig:05_cypher_patternmatching mostra un esempio di come possiamo rappresentare dei pattern in Cypher.

#figure(
  image("../images/ch05/05_cypher_patmatching.png", width: 90%),
  caption: "Esempio di pattern matching in Cypher per trovare nodi e relazioni specifiche all'interno di un grafo.",
)<fig:05_cypher_patternmatching>

Dato il pattern rappresentato in @fig:05_cypher_patternmatching possiamo andare a *creare* o a *ricercare* nodi e relazioni all'interno del grafo.

#example-box("Creazione della relazione 'Loves' tra 'Dan' e 'Ann'", [
  #align(center)[
    ```Cypher
    CREATE
      (:Person {name: "Dan"})
      -[:LOVES]->
      (:Person {name: "Ann"})
    ```
  ]
])

#example-box("Ricerca delle persone amate da 'Dan'", [
  #align(center)[
    ```Cypher
    MATCH
      (:Person{name: "Dan"})
      -[:LOVES]-> (whom)
    RETURN whom
    ```
  ]
])

Nell'esempio di sopra non è stato specificato che l'entità amata da 'Dan' dovesse essere di tipo `Person`, dunque la query restituirà qualsiasi entità connessa a 'Dan' tramite una relazione di tipo `LOVES`. È tuttavia possibile aggiungere ulteriori vincoli per restringere i risultati ottenuti.

Vediamo ora un esempio leggermente più complesso. Consideriamo il grafo in @fig:05_social_recommendation, che rappresenta una rete sociale in cui gli utenti sono connessi tramite relazioni di amicizia e hanno ristoranti preferiti.

#figure(
  image("../images/ch05/05_social_recommendation.png", width: 75%),
  caption: "Grafo che rappresenta una rete sociale con relazioni di amicizia e ristoranti preferiti.",
)<fig:05_social_recommendation>

Vorremo andare a trovare i ristoranti che sono graditi dagli amici di 'Philip' che servono 'sushi' locati a 'New York'. La query in Cypher per ottenere queste informazioni è la seguente:

#align(center)[
  ```Cypher
  MATCH (person:Person) -[:IS_FRIEND_OF]-> (friend),
        (friend) -[:LIKES]-> (restaurant),
        (restaurant) -[:LOCATED_IN]-> (loc:Location),
        (restaurant) -[:SERVES]-> (type:Cuisine),
  WHERE person.name = 'Philip'
    AND loc.location = 'New York'
    AND type.cuisine = 'Sushi'
  RETURN restaurant.name
  ```
]

=== Introduzione a Cypher
Dopo aver visto qualche esempio di query eseguita in Cypher andiamo a vedere più nel dettaglio la *sintassi* e gli *elementi fondamentali* per costruire query con questo linguaggio.

==== Sintassi

- un *nodo* viene rappresentato tramite delle parentesi tonde `()`, al cui interno possiamo specificare una *label* e delle *proprietà*. Esempio: `(n:Person {name: "Alice", age: 30})`
- una *relazione* viene rappresentata tramite una freccia `-->` o `<--`, al cui interno possiamo specificare una *label* e delle *proprietà* tra parentesi quadre `[]`. Esempio: `-[:KNOWS {since: 2020}]->`
- un *pattern* viene di solito costruito tramite una combinazione di nodi e relazioni: `()-[]-()`, `()-[]->()`, `()<-[]-()`.


===== Componenti di una Query
I due componenti principali di una query in Cypher sono sostanzialmente due:

- *`MATCH`* : viene utilizzato per specificare i pattern da cercare all'interno del grafo.
- *`RETURN`* : viene utilizzato per specificare quali dati che hanno registrato una corrispondenza nella clausola `MATCH` vogliamo vengano restituiti dalla query


#example-box("Basica Query in Cypher 2", [
  #align(center)[
    #block(width: 75%)[
      ```Cypher
      MATCH (m:Movie) // considera tutti i nodi m di tipo Movie
      RETURN m        // restituisce tutti i nodi m trovati
      ```
    ]]
])

#example-box("Basica Query in Cypher 2", [
  #align(center)[
    #block(width: 75%)[
      ```Cypher
      MATCH (p:Person)-[r:ACTED_IN]->(m:Movie)
      RETURN p, r, m
      ```
    ]]

  In questo caso `MATCH` e `RETURN` sono due parole chiave del linguaggio; `p`, `r` e `m` sono delle *variabili* che rappresentano rispettivamente i nodi di tipo `Person`, le relazioni di tipo `ACTED_IN` e i nodi di tipo `Movie`.
])

È anche possibile utilizzare interi pattern come variabili, per esempio nel caso in cui vogliamo vedere dei *path* completi. Lo vediamo nell'esempio che segue.

#example-box("Query di Path in Cypher", [
  #align(center)[
    #block(width: 75%)[
      ```Cypher
      MATCH p = (p:Person)-[r:ACTED_IN]->(m:Movie)
      RETURN p
      ```
    ]]

  In questo caso la *variabile* `p` rappresenta l'intero path che va dal nodo di tipo `Person`, tramite la relazione di tipo `ACTED_IN`, fino al nodo di tipo `Movie`.
])

È anche possibile andare ad accedere in maniera selettiva alle *proprietà* dei nodi e delle relazioni. Per fare ciò la sintassi è `{variable}.{property_key}`. Lo vediamo nell'esempio che segue.

#example-box("Query con Proprietà in Cypher", [
  #align(center)[
    #block(width: 75%)[
      ```Cypher
      MATCH (p:Person)-[r:ACTED_IN]->(m:Movie)
      RETURN p.name, m.title
      ```
    ]]

  In questo caso stiamo restituendo solamente le proprietà `name` del nodo di tipo `Person` e `title` del nodo di tipo `Movie`.
])

#remark[Si noti che questa operazione è molto simile a quella di eseguire una *proiezione* in algebra relazionale o ad applicare costrutti equivalenti in SQL. ]

Un'altra questione che seppur di minore importanza è necessario menzionare è il funzionamento e la gestione del *casing* in questo linguaggio:

- le _label_ di nodi, i _tipi_ delle relazione, le _property key_ sono sempre *case sensitive*
- tutte le _keyword di Cypher_ sono *case insensitive*

=== Indici e vincoli
Un costrutto molto importante è quello dei *vincoli* (constraints), che permettono di imporre delle regole sui dati memorizzati all'interno del grafo, in modo da garantire l'integrità, coerenza dei dati e altre interessanti proprietà.

All'interno di Neo4j e in Cypher è inoltre possibile andare a specificare delle maniere per *ottimizzare* le performance di alcune operazioni, lo strumento utilizzato, similmente a quanto avviene con altre tecnologia è quello degli *indici*.

==== Vincoli (Constraints) Unique
Andiamo a vedere ora il principale vincolo che possiamo andare a specificare in Neo4j, ovvero il vincolo di *unicità*. Questo assolve a due funzioni fondamentali:

- Garantisce che non esistano due nodi con la stessa proprietà chiave-valore per una certa label
- Permette un *accesso molto veloce* a nodi che corrispondono certe coppie "label-property"

Per la creazione di questo vincolo andiamo a utilizzare la seguente sintassi:

#align(center)[
  #block(width: 75%)[
    ```Cypher
    CREATE CONSTRAINT ON (label:Label)
    ASSERT label.property_key IS UNIQUE
    ```
  ]
]

Esistono in verità *tre tipologie* di vincoli di unicità che andiamo di seguito ad illustrare:

- *Unique Node Property*: garantisce che non esistano due nodi con la stessa proprietà chiave-valore per una certa label.
  #align(center)[
    #block(width: 75%)[
      ```Cypher
      CREATE CONSTRAINT ON (label:Label)
      ASSERT label.property_key IS UNIQUE
      ```
    ]
  ]
- *Node Property Existence*: impedisce la creazione di nodi che per una certa label non abbiano valori
  #align(center)[
    #block(width: 75%)[
      ```Cypher
      CREATE CONSTRAINT ON (label:Label)
      ASSERT exists(label.name)
      ```
    ]
  ]
- *Relationship Property Existence*: impone che per un certo tipo di relazione esista sempre una certa proprietà
  #align(center)[
    #block(width: 85%)[
      ```Cypher
      CREATE CONSTRAINT ON ()-[rel:REL_TYPE]->()
      ASSERT exists(rel.name)
      ```
    ]
  ]

==== Indici
Come già visto in altri sistemi e linguaggi, l'utilizzo di *indici* serve a garantire un *lookup* veloce di nodi che soddisfano una certa condizione di tipo "label-property". In Neo4j possiamo creare un indice tramite la
sintassi che segue:

#align(center)[
  #block(width: 75%)[
    ```Cypher
    CREATE INDEX ON :Label(property_key)
    ```
  ]
]

Il lookup efficiente e rapido è garantito quando andiamo ad utilizzare i seguenti *predicati* che utilizzano gli indici by design:

- _Uguaglianza_: `=`, `<>`
- `STARTS WITH`
- `CONTAINS`
- `ENDS WITH`
- Ricerche su *range* di valori
- Ricerche su *valori null*


È importante fare una distinzione tra l'utilizzo di indici in questo contesto e in altri sistemi come quello relazionale: se nel mondo relazionale, l'uso dell'indice è fatto per *cercare righe* di certe tabelle, in un graph db l'indice serve a *cercare nodi* di partenza per una certa query.

=== Scrittura di Query in Cypher: Utilizzi Avanzati
Dopo aver visto le basi del linguaggio Cypher andiamo ora a vedere qualche costrutto più avanzato che ci consentirà di scrivere query più complesse e potenti.

==== Clausola `CREATE`
La clausola `CREATE` viene utilizzata per andare a creare nuovi nodi e relazioni all'interno del grafo. La sintassi è molto simile a quella utilizzata per specificare i pattern nella clausola `MATCH`:

#align(center)[
  #block(width: 85%)[
    ```Cypher
    CREATE (m:Movie(title: 'Mystic River', released:2003))
    RETURN m
    ```
  ]
]

Nell'esempio di sopra stiamo andando a creare un'entità `Movie` con le proprietà `title` e `released` e ritorniamo all'utente l'entità appena creata.

È possibile andare a utilizzare la clausola `CREATE` anche per creare relazioni tra nodi esistenti:

#align(center)[
  #block(width: 85%)[
    ```Cypher
    MATCH (m:Movie {title: 'Mystic River'})
    MATCH (p:Person {name: 'Kevin Bacon'})
    CREATE (p)-[r:ACTED_IN {roles: ['Sean']}]->(m)
    RETURN p, r, m
    ```
  ]
]

In questo caso vediamo come sia stato prima effettuato il *lookup* dei nodi di interesse tramite la clausola `MATCH`, per poi andare a creare la relazione `ACTED_IN` tra i due nodi, con una proprietà `roles` che è una lista che conterrà i ruoli interpretati dall'attore nel film.

#remark[
  Una volta che andiamo ad utilizzare la clausola `CREATE` questa provvederà a creare tutto ciò che viene specificato al suo interno. Nel caso in cui vogliamo creare una relazione tra due nodi abbiamo due possibilità diverse:

  - _entrambi i nodi sono già esistenti_: in tal caso andremo soltanto a creare la relazione
  - _solo uno dei nodi o nessuno esiste_: ipotizzando che la persona con nome `Kevin Bacon` non fosse già esistente, la clausola `CREATE` la avrebbe creata per fare in modo che il path desiderato fosse coerente
]

==== Clausola `SET`
Oltre a creare entità, è possibile anche andare a modificare le proprietà delle entità, per questo scopo utilizziamo la clausola `SET`:

#align(center)[
  #block(width: 85%)[
    ```Cypher
    MATCH (m:Movie {title: 'Mystic River'})
    SET m.released = 2004
    SET m.tagline = 'A movie about life and loss'
    RETURN m
    ```
  ]
]

La query presentata sopra va sia a modificare una proprietà già esistente (`released`), sia ad aggiungerne una nuova (`tagline`).

==== Clausola `MERGE`
La clausola `MERGE` viene utilizzata per creare nodi o relazioni in modalità '*upsert*', combinando le funzionalità di `MATCH` e `CREATE`. In pratica, `MERGE` cerca di trovare un nodo o una relazione che corrisponde al pattern specificato; se non lo trova, lo crea.

#align(center)[
  #block(width: 85%)[
    ```Cypher
    MERGE (p:Person {name: 'Tom Hanks'})
    RETURN p
    ```
  ]
]

#warning-box[

  È importante considerare che l'utilizzo di questa clausola potrebbe portare a risultati inattesi se utilizzata senza la dovuta attenzione.
  Supponiamo di voler andare a rivisitare la l'operazione di upsert presentata sopra, ma questa volta aggiungendo il la proprietà `oscar` alla persona `Tom Hanks`. A una prima occhiata potrebbe venirci in mente di utilizzare la seguente query:

  #align(center)[
    #block(width: 85%)[
      ```Cypher
      MERGE (p:Person {name: 'Tom Hanks', oscar: true})
      RETURN p
      ```
    ]
  ]

  Tuttavia, questa query non funzionerà come ci aspettiamo. Se esiste già un nodo `Person` con il nome 'Tom Hanks' ma senza la proprietà `oscar`, la clausola `MERGE` non lo troverà come corrispondente e creerà un nuovo nodo con la proprietà `oscar` impostata a `true`. Di conseguenza, ci ritroveremo con due nodi distinti per 'Tom Hanks', uno con la proprietà `oscar` e uno senza. La query giusta da utilizzare in questo caso è la seguente:

  #align(center)[
    #block(width: 85%)[
      ```Cypher
      MERGE (p:Person {name: 'Tom Hanks'})
      SET p.oscar = true
      RETURN p
      ```
    ]
  ]
]

È possibile utilizzare la clausola `MERGE` anche per creare relazioni in modalità upsert. Oltre a tutte queste funzionalità, `MERGE` supporta la possibilità di specificare delle *azioni* da eseguire in base al fatto che l'entità sia stata trovata o creata, tramite l'uso delle clausole `ON MATCH` e `ON CREATE`.

#align(center)[
  #block(
    ```Cypher
    MERGE (p:Person {name: 'Your Name'})
    ON CREATE SET p.created = timestamp(), p.updated = 0
    ON MERGE SET p.updated = p.updated + 1
    RETURN p.created, p.updated
    ```,
  )
]


=== Data Ingestion in Neo4j
Dopo aver visto come interrogare la nostra base di dati, andiamo a vedere come effettuare una delle operazioni più importanti nel mondo del data management, ovvero l'*ingestione* dei dati all'interno del database.

Cypher è dotato di una clausola specifica per questo scopo, che permette di partire da un file `.csv`, si chiama appunto *`LOAD_CSV`*. Di seguito ne mostriamo alcune caratteristiche:

- Permette di caricare dati in formato `.csv` da un file locale o da un URL
- Preso in input un file `.csv` fornisce uno *stream* di record che possono essere processati tramite le classiche clausole messe a disposizione da Cypher (`MATCH`, `CREATE`, `SET`, ecc.)
- Supporta l'esecuzione di *operazioni transazionali* sul grafo esistente
- È in grado di convertire i valori letti dal file `.csv` in tipi di dati nativi di Neo4j (es. stringhe, numeri, booleani, ecc.)

Ipotizziamo che il nostro property graph model sia descritto in @fig:05_ingestion_propgraph.

#figure(
  image("../images/ch05/05_ingestion_propgraph.png", width: 70%),
  caption: "Esempio di property graph model che rappresenta persone e film con relazioni",
)<fig:05_ingestion_propgraph>

Per ogni record del file `.csv` da utilizzare per l'ingestion vogliamo distinguere i casi seguenti:

- Creiamo un nodo di tipo `Person` o `Movie` se questo non esiste già:
  #align(center)[
    #block(width: 90%)[
      ```Cypher
      CREATE (:Person {
        name:row.name,
        born:toInt(row.born)
      });
      ```
    ]
  ]
- Cerchiamo nodo di inizio e nodo di fine e creiamo tr loro una relazione:
  #align(center)[
    #block(width: 90%)[
      ```Cypher
      MATCH (m:Movie {title:row.movie}),
            (p:Person {name: row.person}),
      CREATE (p)-[:ACTED_IN {roles:split(r.roles)}]->(m);
      ```
    ]
  ]

Una volta definiti i classici statements da utilizzare per fare ingestion, è necessario andare a mostrare in quale maniera dire a Neo4j di effettuare ingestion:

#align(center)[
  #block(width: 90%)[
    ```Cypher
    [USING PERIODIC COMMIT]   // attiva le transazioni per batch

    LOAD CSV    // statement per iniziare a effettuare ingestion

    WITH HEADERS  // opzionalmente usare la prima riga del file come chiave per gli elementi letti

    FROM "url"    // path o url da cui leggere il file csv

    AS row        // ritorna ogni riga come lista di stringe o mappa

    FILEDTERMINATOR ";"   // specifica qual è il separatore dei valori


    ... gli altri statement che specificano come fare ingestion ...
    ```
  ]
]
