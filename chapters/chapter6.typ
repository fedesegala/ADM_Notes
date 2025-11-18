
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

= Gestione di Dati Distribuiti
Dopo aver introdotto varie famiglie di basi di dati, e aver visto come in moltissimi contesti, la loro nascita è dovuta al fatto di permettere una scalabilità orizzontale, andremo ora a vedere come effettivamente queste basi di dati permettono di gestire *dati distribuiti* su diversi nodi.

== Concetti di Base
Come già menzionato, il principio alla base delle basi di dati distribuite è quello della *scalabilità*. Nel particolare, esistono due tipologie di scalabilità di cui si può parlare:

- *Scale up* (o _verticale_): consiste nell'aggiunta di più potenza computazionale ad un singolo server che ospita la base di dati. Questo consente tipicamente di migliorare le prestazioni, ma ha dei limiti fisici e di costo.
- *Scale out* (o _orizzontale_): consiste nell'aggiunta di più nodi (server) al sistema di database. Questo approccio consente di distribuire il carico di lavoro e i dati.

Quando andiamo a parlare di basi di dati distribuite, andremo a riferirci alle seguenti componenti fondamentali:

- *Database distribuito*: si tratta di un insieme di dati che sono _logicamente interconnessi_
- *DBMS distribuito*: si tratta si un sistema per la gestione di _database distribuiti_, che ha la fondamentale capacità di rendere la *distribuzione trasparente*

==== Trasparenza
Proprio questo concetto di *trasparenza* è fondamentale da approfondire. In generale per un utente non dovrebbe essere rilevante come internamente il DBMS gestisce lo storage dei dati e l'esecuzione di query. Esistono diverse tipologie di trasparenza:

- *Access Transparency*: l'accesso ai dati è indipendente dalla struttura della rete o dall'organizzazione fisica dei dati.
- *Location Transparency*: gli utenti non devono conoscere come i dati sono distribuiti.
- *Replication Transparency*: gli utenti non devono conoscere se stanno accedendo a dati replicati o meno.
- *Fragmentation Transparency*: la frammentazione e lo sharding sono tipicamente gestiti internamente. Un utente dovrebbe poter effettuare query alla base di dati come se fosse un'unica entità, senza preoccuparsi di come i dati sono stati frammentati.
- *Migration Transparency*: i dati possono essere spostati tra nodi senza che gli utenti ne siano consapevoli.
- *Concurrency Transparency*: il sistema deve gestire l'accesso concorrente ai dati in modo che gli utenti non debbano preoccuparsi di conflitti o problemi di coerenza.
- *Failure Transparency*: il sistema deve essere in grado di gestire guasti dei nodi o della rete senza che gli utenti ne siano consapevoli.

#pagebreak()

== Guasti nei Sistemi Distribuiti
È importante andare a considerare come in un sistema distribuito, i guasti sono inevitabili. Esistono diverse tipologie di guasti che possono verificarsi. Lo scopo di questa sezione è quello di andare a presentarli brevemente assieme alle tecniche più comuni per mitigarli.

Il primo caso, più semplice è quello in cui a guastarsi sia un singolo nodo (server del sistema). In questo caso andremo a parlare di *server failure*. @fig:0601 mostra un'illustrazione di questo tipo di guasto.

#figure(
  image("../images/ch06/01_server_failure.png", width: 55%),
  caption: "Illustrazione di un guasto su un nodo singolo in un sistema distribuito.",
)<fig:0601>

Un'altra tipologia di guasto è quella di *network failure*, in cui la comunicazione tra nodi viene interrotta. Questo può essere causato da problemi di rete, congestione o guasti hardware. @fig:0602 mostra un'illustrazione di questo tipo di guasto.

#figure(
  image("../images/ch06/02_netfail.png", width: 45%),
  caption: "Illustrazione di un guasto di rete in un sistema distribuito.",
)<fig:0602>

Nell'eventualità in cui si verifichino *guasti multipli*, potremmo trovarci in una condizione chiamata *network partitioning*, in cui la rete di comunicazione trai server risulta divisa in più segmenti che non possono comunicare tra di loro. @fig:0603 mostra un'illustrazione di questo tipo di guasto.
#remark[
  È importante considerare che un segmento di partizionamento potrebbe essere composto anche da un singolo nodo, nel caso in cui questo risulti isolato dal resto della rete.

  Si noti come spesso e volentieri le situazioni di *network partitioning* siano estremamente difficili da distiguere rispetto a quelle di *server failure*, in quanto da un nodo potrebbe sembrare che un altro nodo sia semplicemente non raggiungibile.
]

#figure(
  image("../images/ch06/03_netpartition.png", width: 47%),
  caption: "Illustrazione di un partizionamento di rete in un sistema distribuito.",
)<fig:0603>

== Protocolli Epidemici

=== Background
Uno dei punti cruciali all'interno di un sistema distribuito è la *propagazione* delle *informazioni*. In un sistema distribuito, si tratta di un compito complesso, per due principali motivi:

- _Perdita di messaggi_: in una rete distribuita, i messaggi possono essere persi a causa di guasti di rete, congestione o altri problemi, e maggiore il numero di nodi e connessioni, maggiore è la probabilità che questo accada.
- _Forte agitazione dei nodi_: in un sistema distribuito, i nodi possono entrare e uscire dalla rete in qualsiasi momento, rendendo difficile mantenere una visione coerente dello stato del sistema.

Una delle tecniche più interessanti per mitigare questi problemi è l'utilizzo di *protocolli epidemici*, _protocolli peer to peer_ ispirati al modo in cui le infezioni o il 'gossip' si diffondono in una popolazione.
Per capire il motivo dietro al quale utilizziamo una modalità peer to peer, consideriamo il caso in cui usassimo un modello *point to point*: per utilizzare questa strategia ogni nodo dovrebbe quantomeno essere a conoscenza dell'esistenza di tutti gli altri nodi. Per garantire questo avremmo due possibilità:

- Ogni nodo mantiene una lista di tutti gli altri nodi: questo approccio non scala bene, in quanto ogni volta che un nodo entra o esce dalla rete, tutti gli altri nodi devono essere aggiornati.
- Utilizzare un nodo centrale per mantenere la lista dei nodi: questo approccio introduce un singolo punto di fallimento e può diventare un collo di bottiglia.

Il ruolo dei protocolli epidemici è dunque quello di permettere propagare le informazioni ricevute da un nodo a tutti gli altri, nel modo più efficiente possibile, e con la massima affidabilità possibile. All'interno di un protocollo epidemico, ogni nodo potrebbe trovarsi in uno dei seguenti stati:

- *Infetto*: il nodo ha ricevuto l'informazione e la sta _propagando ad altri nodi_
- *Suscettibile*: il nodo non ha ancora ricevuto l'informazione, ma è in grado di riceverla.
- *Rimosso*: il nodo ha ricevuto l'informazione, ma non la propaga più ad altri nodi.+

Il motivo per cui un i nodi possono essere infetti o suscettibli appare abbastanza chiaro: senza nodi suscettibili, l'informazione non si potrebbe propagare, e in modo analogo senza nodi infetti, non ci sarebbe nessuno a propagarla. Per quanto riguarda lo stato di *rimosso* invece, questo viene introdotto per evitare che l'informazione venga propagata all'infinito. Per fare questo i nodi infetti possono decidere di diventare rimossi dopo un certo periodo di tempo, o dopo aver propagato l'informazione ad un certo numero di nodi.

=== Varianti di Protocolli Epidemici
Esistono diverse varianti di protocolli epidemici, ognuna con le proprie caratteristiche e vantaggi. Di seguito andiamo a presentarne alcune.

==== Variante Anti-Entropica
Un approccio di tipo *anti-entropico* è trai più semplici che si possono applicare. Ogni nodo in questo protocollo può essere soltanto *infetto* o *suscettibile*. I nodi infetti _periodicamente_ propagano l'informazione ai loro nodi vicini suscettibili. Questo processo continua fino a quando tutti i nodi sono stati infettati.

Il problema maggiore di questo approccio consiste nell'*eccessivo utilizzo di banda* e che ad ogni round, ogni nodo controlla che i suoi vicini siano suscettibili a nuove informazioni.

==== Approccio Rumor Spreading
La propagazione delle informazione viene avviata solamente nel momento in cui un nodo riceve *nuova informazione* o può essere attivata in maniera *periodica*. La differenza rispetto a prima è che in questo caso le dinamiche di propagazione sono differenti:

- La quantità di nodi infetti viene fatta decrescere nel tempo mano a mano che il numero di nodi *rimossi* aumenta
- Ogni server può passare da *infetto* a *rimosso* sulla base di alcune euristiche, per esempio con una certa probabilità ad ogni round, o dopo aver inviato l'informazione ad un certo numero di nodi.

=== Hash Trees
Come già anticipato, è necessario garantire che ogni coppia di nodi possa stabilire quali informazioni sono rispettivamente note ad ognuno. Per questa operazione si potrebbe pensare di applicare una semplice operazione di *differenza insiemistica*. Tuttavia un'operazione di questo tipo potrebbe risultare inefficiente, richiedendo un numero di operazioni pari ad $O(n)$, dove $n$ è il numero di elementi da confrontare. Per ovviare a questo problema, si può utilizzare una struttura dati chiamata *hash tree* (o *merkle tree*).

Un *hash tree* può essere visto come un *indice* gerarchico di hash. Ogni nodo foglia dell'albero rappresenta un blocco di dati, e ogni nodo interno rappresenta l'hash dei suoi nodi figli. In questo modo, ogni nodo può rappresentare un insieme di dati tramite un singolo hash. Questo permette di confrontare rapidamente grandi insiemi di dati. @fig:06_merkletree ne mostra un esempio.

#figure(
  image("../images/ch06/04_merkletree.png", width: 80%),
  caption: "Esempio di Hash Tree con 8 nodi foglia data una lista di messaggi A,B,C,D,E,F,G,H.",
)<fig:06_merkletree>

Nel caso in cui tutti i messaggi ricevuti da due nodi siano gli stessi, anche gli hash dei nodi radice saranno gli stessi. In caso contrario, i nodi possono scendere lungo l'albero confrontando gli hash dei nodi figli per identificare quali blocchi dati differiscono.

#remark[Chiaramente l'utilizzo di una struttura come gli Hash Tree implica che tutti i nodi della rete devono concordare sull'ordinamento dei messaggi che pervengono e su una funzione di hashing univoca.]

== Frammentazione ("Sharding")
Una delle tecniche più comuni per la gestione di dati grandi e massivi è quella di ricorrere alla *frammentazione* degli stessi. L'idea è quella di suddividere appunto grandi quantità di dati in *frammenti più piccoli* che possano essere gestiti in maniera più agile. Di seguito presentiamo vantaggi e svantaggi di questa tecnica.

- *Località dei dati*: possiamo delegare ad un nodo locale la gestione e la computazione di operazioni su un frammento di dati comunicando il risultato finale agli altri nodi #emoji.checkmark.box
- *Riduzione dei costi di comunicazione*: svolgendo le operazioni a livello di singolo frammento in locale, è possibile ridurre la quantità di dati che deve essere trasferita nella rete #emoji.checkmark.box
- *Performance migliorate*: operazioni su frammenti più piccoli di dati tendono ad essere più veloci rispetto a operazioni su grandi insiemi di dati #emoji.checkmark.box
- *Indici più efficienti*: gli indici possono essere creati e mantenuti più facilmente su frammenti più piccoli di dati #emoji.checkmark.box
- Possibilità di applicare *load balancing*: distribuendo i frammenti di dati tra diversi nodi, è possibile bilanciare il carico di lavoro e migliorare le prestazioni complessive del sistema #emoji.checkmark.box
- *Query più complesse*: le query che coinvolgono più frammenti di dati possono diventare più complesse da gestire e ottimizzare #emoji.crossmark
- *Gestione più complessa*: operazioni di backup e recovery possono diventare più complesse in un sistema frammentato #emoji.crossmark

=== Allocazione
Ogni volta che tentiamo di memorizzare delle nuove informazioni queste vengono suddivise in *unità di allocazione* e serve decidere quanti e quali nodi dovranno essere impiegati per memorizzare i frammenti. Un'altra tematica importante è quella del *load balancing*: se tutti i frammenti andassero a finire su un singolo nodo, questo diventerebbe un collo di bottiglia per l'intero sistema. Abbiamo diverse possibilità per gestire l'allocazione:

- *Range-based allocation*: supponiamo che i nodi abbiamo un identificativo numerico. In questo caso possiamo decidere di allocare i frammenti in base a degli intervalli di identificativi. Per esempio, il nodo 1 potrebbe essere responsabile per i frammenti con ID da 0 a 99, il nodo 2 per quelli da 100 a 199, e così via. Questo approccio è semplice da implementare, ma può portare a squilibri se la distribuzione dei dati non è uniforme.
  #example-box("Distribuzione uniforme vs. non-uniforme")[
    sEmemorizziamo date di nascita con solo giorno e mese, la distribuzione sarà pressoché uniforme, mentre anando a memorizzare anche gli anni questo sarà diverso dal momento che alcuni anni sono più rappresentati di altri
  ]

- *Cost-based allocation*: il nodo sul quale verranno allocati i frammenti viene scelto in base al costo stimato di accesso ai dati. Questo approccio può essere più complesso da implementare, ma può portare a una migliore distribuzione del carico di lavoro.
- *Hash-based allocation*: utilizza una funzione di hash per mappare i frammenti ai nodi. Si tratta di una tecnica molto simile a quella 'range-based' con il vantaggio di distribuire i frammenti più uniformemente tramite le funzioni di hash.

Per quanto la *hashed based allocation* sembri essere una tecnica molto valida, questa presenta due importanti criticità:

- necessità di una conoscenza a priori del numero di nodi nel sistema
- nel momento in cui un nodo subisse dei guasti, molti hashcodes verrebbero invalidati, richiedendo una riallocazione massiva dei frammenti

==== Consistent Hashing
Una tecnica molto interessante per ovviare ai problemi della *hash-based allocation* è quella del *consistent hashing*. In questo approccio la funzione di hash viene calcolata sia sui *nodi* che sui *frammenti di dati*.

Tutti i valori di hash vengono mappati su un *hash ring*, un intervallo circolare di valori di hash. Ogni frammento di dati viene allocato al nodo il cui valore di hash è più vicino al valore di hash del frammento, procedendo in senso orario lungo l'anello. @fig:06_consistent_hashing ne mostra un esempio.

#figure(
  image("../images/ch06/05_consistent_hashing.png", width: 45%),
  caption: "Esempio di Consistent Hashing con 3 nodi e 6 frammenti di dati.",
)<fig:06_consistent_hashing>

Nel caso di *rimozione di un nodo*, tutti i frammenti del nodo vengono copiati nel nodo successivo nell'anello. Questa situazione è chiaramente illustrata in @fig:06_consistent_hashing_removal.

#figure(
  image("../images/ch06/06_consistent_hashing_removal.png", width: 45%),
  caption: "Esempio di Consistent Hashing con rimozione di un nodo.",
)<fig:06_consistent_hashing_removal>

In maniera abbastanza simile, nel caso in cui si proceda con l'*aggiunta di un nodo*, andremo a considerare il nodo precedente nell'anello e riallocheremo tutti i frammenti che ora ricadono sotto la responsabilità del nuovo nodo. @fig:06_consistent_hashing_addition illustra questa situazione.

#figure(
  image("../images/ch06/07_consistent_hashing_addition.png", width: 45%),
  caption: "Esempio di Consistent Hashing con aggiunta di un nodo.",
)<fig:06_consistent_hashing_addition>

Ciò che manca ora è capire come andare a gestire lo stato di questo anello. Supponiamo di avere un client che prova a connettersi in scrittura al nostro sistema distribuito. Per capire in quale nodo scrivere i dati dovremo:

- Calcolare l'hash di un frammento di dati, contattare un nodo casuale in scrittura. A questo punto abbiamo due possibilità:
- Il nodo ha conoscenza dell'intero anello: in questo caso può calcolare direttamente il nodo responsabile per il frammento e inoltrare la richiesta.
- Il nodo può provare ad inoltrare la richiesta al nodo successivo nell'anello, che a sua volta può fare lo stesso fino a quando la richiesta non raggiunge il nodo responsabile.

#figure(
  image("../images/ch06/08_consistent_hashing_virtual.png", width: 50%),
  caption: "Illustrazione dell utilizzo di nodi virtuali nel Consistent Hashing.",
)<fig:06_consistent_hashing_virtual>


Evidentemente la seconda opzione è quella che potrebbe richiedere meno sforzo di mantenimento dello stato dell'anello, ma potrebbe richiedere più tempo per raggiungere il nodo responsabile. Per mantenere lo stato dell'anello, l'unica informazione necessaria in ogni nodo è l'identificativo del nodo successivo nell'anello.

Spesso e volentieri, non è verosimile che all'interno di un sistema distribuito tutti i nodi abbiamo la stessa capacità computazionale e di storage. In una situazione tale, potremmo non voler distribuire i frammenti in maniera uniforme, andando a prediligere nodi con maggior capacità. Per risolvere questo requisito, possiamo _simulare la presenza di nodi aggiuntivi_ gestiti da uno stesso server, chiamati *nodi virtuali*. Utilizzando questo approccio possiamo assegnare più nodi virtuali a server con maggior capacità, e meno nodi virtuali a server con minore capacità. In questo modo, i frammenti di dati verranno distribuiti in maniera proporzionale alla capacità di ogni server. @fig:06_consistent_hashing_virtual illustra questo concetto.


== Replicazione dei Dati
Oltre a frammentare i dati per rendere le computazioni più efficienti e sostenibili, un'altra tecnica molto comune per la gestione di dati distribuiti è quella della *replicazione*. In questo contesto ci sono due termini che sono importanti da conoscere:

- Le copie dei dati che vengono effettuate sono chiamate *repliche*
- Il numero di nodi su cui le repliche sono memorizzate è chiamato *replication factor*

L'impiego di questa tecnica serve sostanzialmente a due scopi:

- *Affidabilità e disponibilità*: avendo più copie dei dati distribuiti su diversi nodi, il sistema può continuare a funzionare anche in caso di guasti di uno o più nodi.
- *Minor Latenza*: le repliche possono essere utilizzate per effettuare load balancing, e parallelizzazione delle letture, riducendo la latenza di accesso ai dati.

Ovviamente la replicazione dei dati introduce anche delle sfide, tra cui:
- *Coerenza dei dati*: mantenere tutte le repliche aggiornate può essere complesso
- *Concorrenza*: gestire accessi concorrenti ai dati replicati può portare a conflitti

=== Replicazione Master-Slave
Si tratta di una delle architetture di replicazione più semplici. In questo modello, un nodo viene designato come *master* mentre gli altri nodi vengono scelti come *slave*. Di seguito andiamo ad elencarne le peculariatà:

- Tutte le operazioni di *scrittura e aggiornamento* sono svolte sul nodo *master*
- Dopo una certa quantità di tempo, il master propaga le modifiche agli *slave*
- Le operazioni di *lettura* possono essere svolte su qualsiasi nodo, sia master che slave

Chiaramente, questo modello presenta un grosso svantaggio: il nodo master rappresenta un *single point of failure*. In caso di guasto del master, il sistema non può più accettare operazioni di scrittura fino a quando un nuovo master non viene eletto. @fig:06_masterslave da una rappresentazione schematica del funzionamento di questa architettura.
#figure(
  image("../images/ch06/09_masterslave.png", width: 90%),
)<fig:06_masterslave>

=== Replicazione Multi-record
Questo approccio si ispira al modello master-slave introducento alcune modifiche. Sostanzialmente ogni nodo nel sistema può agire sia come *master* per certe informazioni, sia come *slave* per altre.

Ogni nodo può accettare operazioni in *scrittura* per dati di sua competenza, e propagare le modifiche agli altri nodi. Le operazioni di *lettura* possono essere svolte su qualsiasi nodo. @fig:06_multirecord illustra questo concetto.

Per andare a sincronizzare le modifiche trai vari nodi, abbiamo a disposizione due possibili strategie:

- *Replicazione immediata*: ogni volta che un nodo master viene modificato, queste modifiche sono immediatamente propagate agli altri nodi. Questo approccio garantisce una maggiore coerenza, ma può introdurre latenza nelle operazioni di scrittura.

- *Replicazione differita*: le modifiche vengono propagate agli altri nodi dopo un certo intervallo di tempo o quando viene raggiunta una certa soglia di modifiche. Questo approccio può migliorare le prestazioni, ma può portare a situazioni di incoerenza temporanea trai nodi.

#figure(
  image("../images/ch06/10_multirecord.png", width: 100%),
)<fig:06_multirecord>

=== Replicazione Multi-Master
Questo approccio, detto anche "update-anywhere", permette a qualsiasi nodo di accettare operazioni di scrittura e aggiornamento. Si tratta di un approccio che consente *maggiore disponibilità* e *tolleranza ai guasti*. Permette di avere *tempi di risposta migliorati*. Tuttavia, questo modello introduce della importanti sfide legate alla *coerenza dei dati*: spesso si rende infatti necessario implementare meccanismi di risoluzione dei conflitti per gestire situazioni in cui più nodi tentano di aggiornare gli stessi dati contemporaneamente.

#figure(
  image("../images/ch06/11_multimaster.png", width: 90%),
)<fig:06_multimaster>

@fig:06_multimaster illustra il funzionamento di questa architettura. Ogni nodo può accettare operazioni di scrittura e aggiornamento, e le modifiche vengono propagate agli altri nodi. In caso di conflitti, il sistema deve essere in grado di risolverli in modo coerente.

=== Guasti e Recovery
Avendo discusso la replicazione dei dati, il prossimo passaggio è quello di andare a comprendere come i guasti vengano gestiti in un'architettura distribuita. Ipotizziamo di avere un *replication factor* di *2*. Nel caso in cui uno dei due server subisse un guasto, o fosse momentaneamente non raggiungibile, l'altro server dovrebbe essere in grado di continuare a servire le richieste di lettura e scrittura. Nel momento poi in cui il server guasto riprendesse a funzionare, sarà necessaria una *sincronizzazione* con l'altro server per portare il sistema in uno stato coerente. Questa situazione è illustrata in @fig:06_failurerecovery1.

#figure(
  image("../images/ch06/12_failurerecovery1.png", width: 70%),
  caption: "Illustrazione di un guasto di signolo server con replication factor = 2.",
)<fig:06_failurerecovery1>

Nel caso però in cui, sempre con un *replication factor* di *2*, se il secondo server fallisse prima che il primo possa tornare disponibile, tutte le scritture accettate dal secondo server non saranno visibili dal primo. Questo scenario è illustrato in @fig:06_failurerecovery2.

#figure(
  image("../images/ch06/13_failurerecovery2.png", width: 70%),
  caption: "Illustrazione di un guasto di entrambi i server con replication factor = 2.",
)<fig:06_failurerecovery2>

In questo caso, nel momento in cui entrambi i server torneranno funzionanti, tutte le richieste di scrittura accettate in maniera indipendente dai serer andranno *riconciliate*. Questa situazione ci mette davanti ad un quesito fondamentale, legato a _quale sia il corretto *replication factor*_ da utilizzare. Tendenzialmente una convenzione accettata abbastanza in generale è quella di utilizzare un replication factor pari a 3.

Di seguito andiamo a presentare due tecniche molto comuni per la gestione dei guasti e della successiva riconciliazione dei dati.

==== Hinted Handoff
Questa tecnica viene utilizzata per gestire i guasti temporanei dei nodi in un sistema distribuito. Nel seguente elenco puntato andiamo a mostrarne il flusso operativo:

- nel momento in cui una replica non è disponibile, le richieste in scrittura vengono *delegate* ad un altro nodo disponibile
- il nodo che riceve le richieste di scrittura riceve un *hint* che indica quale nodo era il destinatario originale della scrittura, in modo tale da poter inoltrare la scrittura non appena il nodo originale torni disponibile

==== Read Repair
Nell'utilizzo di questa tecnica un _coordinatore_ manda una serie di richieste di lettura alle repliche da lui conosciute. Nel momento in cui i nodi rispondono al coordinatore, questo effettua un *majority vote* per capire cosa rispondere al client.

Oltre a fornere risposte il più coerenti possibili al client, il coordinatore si ocupa di inviare istruzioni alle repliche che hanno risposto con dati incoerenti in moo da *sincronizzare lo stato* del sistema.

#remark[
  Si noti come, nel caso in cui utilizzassimo un singolo nodo coordinatore, andremmo ad introdurre un *single point of failure*. Per ovviare a questo problema non viene mai scelto un nodo coordinatore fisso, ma questo viene eletto secondo un protocollo di *leader election* ogni volta che un client invia una richiesta.
]

== Gestione della Concorrenza
Come già menzionato in precedenza, uno dei principali problemi all'interno di un sistema distribuito è quello della gestione della *concorrenza*. Potremmo infatti trovarci nella situazione in cui più componenti tentino di lavorare sugli stessi dati in contemporanea. In questi casi, è fondamentale garantire che tutti i nodi rimangano sincronizzati e l'operazione venga conclusa in maniera coerente.

==== Commit a 2 Fasi
Il *Two-Phase Commit (2PC)* è un protocollo utilizzato per garantire che le *transazioni distribuite* vengano completate in modo atomico, anche in presenza di guasti. L'idea è che tutti gli agenti devono essere d'accordo sulla finalizzazione di una trasazione.  Il protocollo si divide in una fase di *voting* e in una fase di *decisione*. Anche in questo caso avremo bisogno di un nodo che funga da *coordinatore*. Di seguito andiamo ad elencare alcune altre specificità:

- Il fallimento di un singolo 'agente' implica che l'intera transazione venga abortita
- Lo stato che si interpone tra le due fasi è detto  '*doubt-phase*', dato che gli agenti non sanno se la decisione del coordinatore sarà di committare o abortire la transazione
- In caso di guasto del coordinatore, gli agenti rimangono bloccati senza poter committare o abortire


#figure(
  grid(
    columns: 2,
    gutter: 2mm,
    image("../images/ch06/14.1_commit.png", width: 100%), image("../images/ch06/14.2_commit.png", width: 100%),
  ),
  caption: "Illustrazione del Two-Phase Commit: a sinistra un commit riuscito, a destra un commit abortito.",
)

== Proprietà dei Database Distribuiti
Per concludere questa panoramica sulle basi di dati distribuite, andiamo a presentare le *proprietà* che queste devono / possono garantire.

==== Consistenza
Quando un nodo modifica un valore in una replica, il valore dovrebbe essere modificato in tutte le repliche; o se non immediatamente, almeno prima che ci sia la necessità di leggere un certo dato. Si tratta di un processo particolarmente *costoso* nel caso in cui venga utilizzato un *replication factor grande*. Un modo per implementarlo potrebbe consistere nel mantenere bloccate in lettura tutte le repliche fino a quando tutte non siano state aggiornate.

==== Disponibilità
In un sistema distribuito, è fondamentale che ogni richiesta di lettura o scrittura riceva una risposta anche in presenza di guasti. In particolare vengono tenute in considerazione due _metriche_: *efficienza* in risposta alle query e *bassi tempi di risposta*.

==== Tolleranza alle Partizioni
Un sistema distribuito deve essere in grado di continuare a funzionare anche in presenza di _partizioni di rete_. Questo significa che anche se alcuni nodi non possono comunicare tra di loro, il sistema deve essere in grado di accettare e processare le richieste.

=== Congettura di Brewer
Dopo aver definito le proprietà, in questa sezione andiamo a presentare la *congettura di Brewer* che stabilisce una sorta di relazione tra queste proprietà.

#theorem(title: "Congettura CAP di Brewer")[
  Date le proprietà sopra elencate (_consistency, availability, partition tolerance_), in un sistema distribuito è possibile garantire *al massimo due* di queste proprietà contemporaneamente.
]

In sostanza, in base ai requisiti del sistema che abbiamo la necessità di implementare, andremo a scegliere due delle proprietà che vogliamo andare a garantire. Per esempio, in un sistema in cui è richiesta _alta disponibilità_, è sarà necessario sacrificare la consistenza a favore di una maggiore tolleranza alle partizioni.

Sempre in merito alla consistenza, possiamo distinguere tra due principali modelli:

- *Consistenza forte*: dopo un aggiornamento, ogni lettura successiva restituirà il valore aggiornato e corretto
- *Consistenza debole*: il sistema non garantisce che dopo un aggiornamento le letture seguenti restituiscano il valore aggiornato immediatamente.

Proprio in merito a questa forma _rilassata_ di consistenza, possiamo introdurre due concetti. Il primo è quello di *finestra di inconsistenza*, che rappresenta un intervallo di tempo tra un aggiornamento il momento in cui tutte le repliche non sono ancora state aggiornate. Durante questa finestra, le letture potrebbero restituire valori obsoleti.

Dato il concetto di finestra di inconsistenza, possiamo introdurre la nozione di *eventual consistency* che garantisce che, in _assenza di aggiornamenti_, tutte le repliche convergeranno verso lo stesso valore dopo un certo periodo di tempo, tale periodo è appunto la finestra di inconsistenza.

Uno dei metodi utilizzato per cercare di ottenere consistenza in un sistema distribuito è quello di utilizzare il concetto di *quorum*. In questo approccio, per ogni operazione di lettura o scrittura viene richiesto un numero minimo di repliche per completare l'operazione. Questo concetto potrà essere meglio approfondito all'interno del corso di sistemi distribuiti.
