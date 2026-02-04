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
#import "chapter10.typ": *

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

= Gestione di Transazione e Concorrenza
In questo capitolo andremo a trattare gli ultimi componenti fondamentali dello storage engine di una DBMS: il modulo di gestione della concorrenza e quello di gestione delle transazioni.

Possiamo, anche senza aver visto in dettaglio il loro funzionamento, immaginare come questi due componenti siano strettamente collegati: sappiamo infatti che trai compiti fondamentali di una base di dati c'è quelli di garantire l'integrità dei dati, e questo è possibile solo se si riesce a gestire correttamente la concorrenza tra le operazioni che vengono eseguite sulla base di dati, e se si riesce a garantire che le transazioni vengano eseguite in modo atomico, consistente, isolato e durevole. 

== Gestore delle Transazioni
Andiamo a trattare prima il modulo di gestione delle transazioni dal momento che questo viene utilizzato dal modulo di gestione della concorrenza. 

#definition(title: "Transazione")[
  Una transazione, dal punto di vista di un programmatore, è un unità di lavoro sequenziale da eseguire sulla base di dati che garantisce le proprietà di atomicità, consistenza, isolamento e durabilità (ACID).
]

Possiamo vedere ogni transazione come un insieme di operazione di *lettura* e *scrittura* sulla base di dati, che vengono iniziate tramite un comando *`beginTransaction`* e che sono concluse tramite un comando *`commit`* o *`rollback`*.

Il motivo per cui è possibile che terminino con un `rollback` è che, durante l'esecuzione di una transazione, possono verificarsi degli errori che impediscono un completamento corretto, come ad esempio un errore di sintassi in una query o una violazione di vincoli, che può avvenire a causa dell'esecuzione di operazioni concorrenti. In questi casi, è necessario annullare tutte le modifiche operate dalla transazione corrente. 

#remark[
  Il modulo di gestore delle transazioni si occupa di garantire le proprietà di *atomicità* e *durabilità* delle transazioni, mentre il modulo di gestione della concorrenza si occupa di garantire *isolamento*.
]

=== Requisiti di funzionamento

In questa sezione andiamo brevemente a descrivere i requisiti di funzionamento di questo modulo. 
Come già anticipato, sappiamo che ha il compito di garantire *atomicità* e *durabilità* delle transazioni. In senso pratico è richiesto che le transazioni vengano svolte in maniera completa, oppure che non vengano svolte affatto, e che le modifiche operate da una transazione vengano mantenute anche in caso di crash del sistema.

Supponiamo per esempio avere cinque transazioni all'interno del nostro sistema, alcune delle quali vanno a buon fine, mentre altre non fanno in tempo a completarsi a causa di un crash di sistema. Possiamo vedere questa situazione rappresentata in @fig_11_01_transaction_system_crash.

#figure(
  image("/assets/11_01_transaction_system_crash.png", width: 50%),
  caption: [Esempio di crash del sistema durante l'esecuzione di alcune transazioni]
)<fig_11_01_transaction_system_crash>

In questo caso vorremmo che dopo il ripristino del sistema, le transazioni $T_1, T_2, T_3$ siano visibili e permanenti nel sistema, mentre le transazioni $T_4$ e $T_5$ non siano visibili e non abbiano modificato lo stato del sistema.

=== Ciclo di vita di una transazione
Prima di introdurre come vengono gestite le transazioni all'interno del sistema, andiamo a vedere quali sono gli stati in cui una transazione può trovarsi durante il suo ciclo di vita. 

Possiamo vedere una transazione come un oggetto che può trovarsi in uno dei seguenti stati:

- una transazione diventa *attiva* quando viene iniziata tramite il comando *`beginTransaction`*, mentre la transazione è attiva si susseguono una serie di operazioni di lettura e scrittura sulla base di dati;

- ad un certo punto la transazione potrà essere utilizzato il comando *`commit`* tramite il quale si indica che non è più possibile effettuare operazioni di lettura o scrittura sulla base di dati, e che la transazione è pronta per essere resa permanente, in questo stato la transazione si trova nello stato di *partially committed*; 

- in alternativa al comando *`commit`* è possibile utilizzare il comando *`abort`* tramite il quale si indica che la transazione deve essere annullata, in questo caso la transazione passa allo stato di *failed*, questo comando viene tipicamente utilizzato quando si verifica un errore logico durante l'esecuzione di un comando, per esempio una violazione di vincolo, oppure nel caso in cui il sistema venisse spento in maniera 'graceful', ovvero senza un crash improvviso, ci potrebbe essere la possibilità di operare un *`abort`* della transazione;

- dallo stato *partially committed* è soltanto possibile passare allo stato *committed* quando tutte le modifiche sono effettivamente rese permanenti sulla base di dati, oppure allo stato *failed* nel caso in cui si verifichi un errore durante il processo di commit, ad esempio a causa di un crash di sistema.

- mentre la transazione si trova nello stato *failed* viene tipicamente svolto un *rollback* tramite il quale tutte le modifiche operate dalla transazione vengono annullate, e la transazione passa allo stato di *aborted*.

Vediamo il ciclo di vita di una transazione ben rappresentato in @fig_11_02_transaction_lifecycle. 

#figure(
  image("../assets/11_02_transaction_lifecycle.png", width: 60%),
  caption: [Ciclo di vita di una transazione]
)<fig_11_02_transaction_lifecycle>

Abbiamo mostrato come all'interno della vita di una transazione sia possibile che questa venga abortita per diversi motivi. Andiamo a vedere in seguito quali sono le tipologie di failure che possono verificarsi durante l'esecuzione di una transazione.

===== Transaction Failure
Si tratta di un'interruzione della transazione che non danneggia il contenuto della memoria temporanea e di quella permanente. Questo tipo di failure è tipicamente causato da *errori logici* all'interno delle operazioni svolte dalla transazione, come ad esempio una violazione di vincoli di integrità, oppure un comando *`abort`* esplicito. 

===== System Failure
Si tratta di interruzioni del sistema, che può essere inteso sia come il DBMS che come l'intero sistema operativo del server ospitante la base di dati. Questo tipo di failure può essere causato da crash di sistema, errori hardware, o errori software critici. In questo caso il contenuto della memoria temporanea viene perso, mentre il contenuto della memoria permanente è tipicamente preservato. 

===== Media Failure
Questo tipo di failure è tipicamente il più grave, anche noto come *catastrophic failure*. Si tratta di un'interruzione del DBMS che va a causare perdita di informazioni salvate in memoria secondaria. 

=== Compiti del modulo 
Di seguito andiamo ad elencare quelli che sono i compiti principali a cui deve assolvere il modulo di gestione delle transazioni e del ripristino. Questo nome non è mai stato utilizzato in maniera completa, essendoci sempre riferiti a questo modulo come modulo di gestione delle transazioni, ma è importante sottolineare che questo modulo si occupa anche del ripristino del sistema in caso di failure, ed è evidente che lo sia, dal momento che deve garantire durevolezza e atomicità delle transazioni a fronte di possibili failure.

==== Esecuzione di operazioni per conto di una transazione
In primo luogo è fondamentale che che il modulo sia in grado di gestire l'*esecuzione* di `read, write, commit, abort` _per conto di una transazione_. In particolare, sappiamo che a livello dello storage engine viene ricevuto un piano di esecuzione, che utilizza il gestore dei metodi di accesso per accedere alla memoria. Queste operazioni non vengono direttamente eseguite, ma vengono invece prima 'inviate' al modulo di gestione delle transazioni, in modo che possa tenere traccia di tutte le operazioni svolte, nel caso in cui sia necessario un rollback o un ripristino del sistema.

Quello specificato nel paragrafo precedente è il requisito sostanziale del modulo, per fare questo però è necessario che questo modulo svolta altri compiti secondari che sono tutti necessari per garantire il corretto funzionamento del workflow di gestione delle transazioni.

==== Gestione dei log e del ripristino
Come già anticipato, tutte le operazioni che dovrebbero essere svolte da una transazione, prima di passare per il gestore dei metodi di accesso, devono essere 'viste' e tracciate da questo modulo. Per operare questo tracciamento viene utilizzato un meccanismo di *logging*, ovvero di registrazione di tutte le operazioni svolte da una transazione, in modo che sia possibile, in caso di failure, risalire a tutte le operazioni svolte e annullarle o ripristinarle se necessario.

==== Prevenzione di perdita di dati
Come già anticipato, è di fondamentale importanza garantire *durabilità* delle transazioni, e questo è possibile solo se si riesce a prevenire la perdita di dati in caso di failure. Per fare questo è necessario che tutte le modifiche operate da una transazione vengano salvate in modo permanente sulla base di dati, e che queste modifiche vengano mantenute anche in caso di crash del sistema.

==== Ripristino del sistema in caso di failure
In caso di failure di sistema, è compito di questo modulo operare un comando *`restart`* per fare in modo che tutto possa essere ripristinato correttamente, e che le transazioni che erano in corso al momento del crash vengano gestite in modo appropriato, ovvero che quelle che erano in stato *partially committed* vengano completate, mentre quelle che erano in stato *active* vengano annullate e/o fatte ripartire.

Di seguito andiamo ad illustrare in dettaglio come ognuno di questi compiti viene solto all'interno del modulo di gestione delle transazioni e del ripristino, e quali sono le tecniche più comuni utilizzate per garantire il corretto funzionamento di questo modulo.

==== Tecniche di gestione delle transazioni
In queste sezione andiamo ad esplorare in quale modo è possibile andare a rendere questo modulo di delegato all'esecuzione di operazioni per conto di una transazione. Come sappiamo l'unico interesse dal punto di vista del DBMS è quello di gestire quali dati sono letti e/o scritti da/su una base di dati. Per semplificare la trattazione _assumiamo di andare a leggere *pagine* non singoli record_. 

Un'operazione di *lettura* di una pagina *$r_i [x]$*, questa necessita che la pagina sia spostata _dal disco al buffer pool_ nel caso in cui questa non sia già presente nel buffer. 

Un'operazione di *scrittura* di una pagina *$w_i[x]$* viene inizialmente modificata una copia in memoria della pagina la quale viene scritta su disco quando il *gestore del buffer* lo decide. Per questo motivo, se una failure avviene, l'effetto delle operazioni di scrittura potrebbe non essere visibile sul disco. In questi casi è necessario l'utilizzo di tecniche di *recovery*. 

=== Prevenzione in caso di Failure
Di seguito elenchiamo alcuni possibili approcci per prevenire la perdita di dati in caso di failure del sistema: 

- *database backup*: vengono creati dei _dump_ della base di dati su supporti esterni in modo da poter ripristinare la base di dati in caso di perdite di dati. Ovviamente questa soluzione non consente di recuperare le modifiche effettuate dopo l'ultimo backup, ad eccezione di quelle salvate in un log;

- *undo-redo logging*: tramite questa tecnica è possibile tenera traccia di tutte le operazioni svolte da una transazione in maniera da poter annullare o ripristinare le modifiche in caso di failure. Questo meccanismo permette anche il ripristino in caso di crash di sistema: in questo caso infatti, al riavvio del sistema, tutte le transazioni attive vengono abortite, e le modifiche operate dalle transazioni che avevano completato il commit vengono rese permanenti. Ogni record del log ha la seguente struttura: 
    
    - *`(T, begin)`*: indica l'inizio della transazione T;
    - per ogni scrittura *`(T, write, oldValue, newValue)`*; 
    - *`(T, commit)`* o *`(T, abort)`*: indica la fine della transazione T;

  #figure(
  image("/assets/11_03_undo_redo_log.png", width: 70%),
  caption: [Esempio di log per una transazione]
  )<fig_11_03_undo_redo_log>


  @fig_11_03_undo_redo_log mostra un esempio di come questo log possa essere strutturato per una transazione. Il motivo per cui salviamo tutte queste informazioni sta nel fatto che, la strategia di ripristino si basa su due operazioni fondamentali: *undo* e *redo*; l'idea è andare a scorrere il log all'indietro per annullare le modifiche di tutte le transazioni non completate (undo), e andare a scorrere il log in avanti per ripristinare le modifiche relative alle transazioni completate (redo).

- *checkpoint periodici*: per quanto la procedura di undo-redo sembri semplice non è ancora chiaro un punto fondamentale, ossia, _quanto dobbiamo andare all'indietro nel log effettuando undo_. Se infatti guardiamo a @fig_11_01_transaction_system_crash, nel momento in cui $T_5$ ha un crash, $T_3$ sta ancora eseguendo, quindi è necessario un undo di $T_3$, ma questo ragionamento si propaga a catena anche su $T_1$ e $T_2$. Il rischio concreto in cui incorriamo è quello di dover ogni volta effettuare undo per la gran parte delle transazioni, possiamo notare che questo è causato da *transazioni* che vengono eseguite in maniera *interlacciata*. Il principio alla base dei *checkpoint periodici* è proprio quello di andare a creare dei punti di salvataggio nel log in cui tutte le transazioni attive sono completate, in questo modo, in caso di crash, sarà possibile effettuare l'undo soltanto delle transazioni iniziate dopo l'ultimo checkpoint.

==== Creazione dei Checkpoint
Come abbiamo citato, i checkpoint sono un componente chiave di tutta la gestione del ripristino; sappiamo come il DBMS crei periodicamente un checkpoint per andare a minimizzare il tempo necessario per il ripristino in caso di crash, che consisterebbe per la gran parte di operazioni di undo. 
Esistono diversi approcci per la creazione dei checkpoint, andiamo di seguito a vedere i due più comuni.

===== Commit Consistent Checkpoint
Si tratta dell'approccio più *semplice* per la creazione di un checkpoint. In questo caso quando viene deciso di creare un checkpoint si procede come segue: 

- il sistema *non accetta nuove transazioni* fino a completamento del checkpoint

- si *attende il completamento* di tutte le transazioni attive

- viene effettuato un *flush* di tutte le pagine modificate nel buffer pool verso il disco

- viene scritto sul log un *record di checkpoint* che indica che tutte le transazioni sono state completate e che tutte le pagine modificate sono state scritte su disco, tale record sarà utilizzato per fermare la sequenza di operazioni undo

Chiaramente il problema di questo approccio è che il sistema rimane completamente bloccato fino al completamento del checkpoint, il che può essere un problema in sistemi con un alto grado di concorrenza.

===== Buffer Consistent Checkpoint
Si tratta di un approccio più *complesso* per la creazione di un checkpoint, ma che consente di minimizzare il tempo in cui il sistema rimane bloccato. In questa caso non viene atteso il completamento delle transazioni attive ma viene tenuto traccia delle *transazioni attive* al momento della creazione del checkpoint. In questo modo sarà possibile andare più indietro del checkpoint soltanto per le transazioni attive al momento della creazione del checkpoint, evitando di dover annullare tutte le transazioni completate prima del checkpoint.

=== Procedure per Undo e Redo
Per quanto sia già stato spiegato a sommi capi il funzionamento di questa tecnica, è importante andare a mostrare in dettaglio il funzionamento di queste procedure.

#remark[
  L'esistenza di queste procedure assume che qualsiasi operazione di *logging* sia fatta in maniera forzata su disco, in maniera tale che sia sempre possibile operare un ripristino qualora fosse necessario. 
]

Gli algoritmi di ripristino differiscono a causa della informazioni che vengono memorizzate nei log, in come queste informazioni sono strutturate e, ancora più importante, rispetto al *momento in cui le pagine sono scritte nella memoria stabile*. 

Diciamo che un algoritmo di ripristino richiede un *undo* nel caso in cui un aggiornamento di qualche transazione non committed sia presente nella memoria stabile. Se si verifica un errore di transazione o un guasto del sistema, l'algoritmo di ripristino deve annullare gli aggiornamenti copiando l'immagine precedente della pagina dal log al database stabile.

In maniera simile, diciamo che è necessaria un'operazione di *redo* nel caso in cui una transazione è considerata 'committed' prima che tutti i suoi aggiornamenti siano presenti nella memoria stabile. Se si verifica un errore di transazione o un guasto di sistema dopo il commit ma prima che tutti gli aggiornamenti siano resi permanenti, l'algoritmo di ripristino dovrà effettuare un redo degli aggiornamenti copiando l'immagine aggiornata della pagina dal log al database stabile.

Gli algoritmi di ripristino si possono classificare in base al modo in cui gestiscono le operazioni di scrittura e di commit delle transazioni. In particolare, possiamo distinguere: 

- algoritmi *undo-redo*
- algoritmi *redo-only*
- algoritmi *undo-only*
- algoritmi *no undo-no redo*

Di seguito mostriamo quelle che sono note come *Undo* e *No-Undo* policies, ossia le politiche che regolano il momento in cui le modifiche operate da una transazione vengono effettivamente scritte su disco.

===== Deferred Update (No-Undo Policy)
Secondo questo approccio, un aggiornamento di una transazione non può essere scritto sulla memoria stabile prima che la transazione sia terminata con successo (committed). In questo modo non è necessario annullare gli aggiornamenti effettuati in caso di fallimento della transazione, dal momento che questi non sono mai stati scritti su disco.

===== Immediate Update (Undo Policy)
Secondo questo approccio, un aggiornamento potrebbe essere scritto sulla memoria stabile prima che la transazione sia terminata con successo (committed). In questo caso, se la transazione non termina con successo, è necessario annullare gli aggiornamenti effettuati.

Nel caso in cui venga utilizzata questa politica, abbiamo la seguente regola per applicare gli undo (*Write-Ahead Logging* - WAL): se una nuova versione di una pagina è scritta nel DB prima che la transazione termini, allora la vecchia versione della pagina deve essere salvata nel log prima che i cambiamenti della pagina siano scritti su disco. In questo modo, in caso di fallimento della transazione, è possibile recuperare la vecchia versione della pagina dal log.

===== Deferred Commit (No-Redo Policy)
Secondo questo approccio, una transazione si considera terminata con successo solamente una volta che tutte le modifiche operate da questa sono state scritte sulla memoria stabile. In questo modo non è necessario ripristinare gli aggiornamenti effettuati in caso di fallimento del sistema, dal momento che questi sono già stati resi permanenti.

===== Immediate Commit (Redo Policy)
Secondo questo approccio, una transazione si considera terminata con successo non appena viene emesso il comando di *commit*, indipendentemente dal fatto che tutte le modifiche operate da questa siano state scritte sulla memoria stabile. In questo caso, se si verifica un fallimento del sistema prima che tutte le modifiche siano state rese permanenti, è necessario ripristinare gli aggiornamenti effettuati.

Nel caso in cui venga utilizzata questa politica, abbiamo la seguente regola per applicare il redo di una transazione $T$ (*Commit rule*): la nuova version delle pagine deve essere scritta nel log (presente nello storage stabile) prima che la transazione sia considerata committed. 

===== Shadow Paging
Un algoritmo 'no-undo' richiede che tutte le modifiche operate da una transazione siano memorizzate *dopo* che questa è stata committata. Al contrario, un algoritmo 'no-redo' richiede che tutte le modifiche siano memorizzate *prima* che la transazione sia committata. Di conseguenza un algoritmo 'no-undo no-redo' richiede che tutte le modifiche siano nella memoria stabile né prima, né dopo il commit. L'unica alternative è dunque che l'operazione di commit scriva in modo atomico tutte le modifiche operate da una transazione e marchi la transazione come committata.

Questo può essere ottenuto tramite la tecnica dello *shadow paging*: l'implementazione si basa su un indice permanente della memoria che mappa ogni identificatore di pagina (PID) ad nu indirizzo fisico (questo indice è noto come *page table*). Esiste inoltre un *database descriptor* presente ad un indirizzo fisso della memoria il quale contiene un puntatore alla page table.

Quando una transazione inizia, una copia della page table è creata nella memoria stabile e viene utilizzata dalla transazione. Quando una transazione aggiorna per la prima volta una pagina, succede quanto segue: 

- una nuova pagina del database è creata e viene utilizzata come pagina corrente, con indirizzo $p$. La pagina vecchia rimane inalterata e diventa *shadow page*;

- la nuova page table è aggiornata in modo che il PID della pagina aggiornata punti all'indirizzo $p$;

Tutte le operazioni su quella pagina operano sulla nuova copia. Quando la transazione raggiunge il punto di *commit*, il sistema sostituisce tutte le pagine shadow per mezzo di un'azione atomica. È necessaria atomicità in quanto se un fallimento si verificasse durante il commit, la base di dati verrebbe lasciata in uno stato inconsistente. 

@fig_11_04_shadow_paging mostra in maniera concreta il funzionamento di questo approccio. È facile immaginare che questa tecnica possa avere diversi svantaggi: 

- le pagine occupate dai record di una stessa tabella sono sparse per tutta la memoria, causando alta *frammentazione* e *bassa località*;

- è necessario un meccanismo di *garbage collection* per recuperare lo spazio occupato dalle shadow page non più utilizzate;

- è comunque necessario un meccanismo di logging per tenere traccia delle transazioni in corso in modo da poter ripristinare il sistema in di disastri.

- la complessità aumenta nel momento in cui si vuole garantire *concorrenza*

#figure(
  grid(
    columns: 2, 
    column-gutter: -20%,
    image("../assets/11_04_1_shadow_a.png", width: 70%),
    image("../assets/11_04_2_shadow_b.png", width: 65%), 
  ),
  caption: [Esempio di shadow paging: (a) prima dell'aggiornamento di una pagina; (b) dopo l'aggiornamento e commit di una pagina]
)<fig_11_04_shadow_paging>

In generale ci troviamo di fronte al dover scegliere tra le diverse politiche già presentate. In generale utilizzare una politica di tipo *undo-redo* è più efficiente in casi di utilizzo normale, per quanto richieda più risorse in termini di spazio e tempo per il ripristino in caso di failure. Nonostante questo, si tratta della politica più utilizzata nei DBMS moderni.

=== Algoritmo di Ripristino
Dopo aver presentato le diverse tecniche di gestione delle transazioni e di prevenzione in caso di failure, andiamo a mostrare un esempio di algoritmo di ripristino basato su undo-redo logging con write-ahead logging (WAL) e checkpoint periodici, che è tra l'altro l'approccio più comunemente utilizzato nei DBMS moderni.

Di seguito mostriamo, a seconda del tipo di failure, cosa si rende necessario: 

- in caso di *transaction failure* è necessario scrivere sul log il record $(T, "abort")$ e iniziare una procedura di *undo*;
- in caso di un *system failure* è necessario utilizzare un comando di *restart* a partire dall'*ultimo checkpoint*, le transazioni non terminate saranno annullate e le transazioni terminate saranno ripristinate; 
- in caso di *media failure* sarà necessario un *cold restart* a partire dall'ultimo backup, seguito da un comando di *restart* per ripristinare le transazioni completate dopo il backup (ipotizzando che il log sia ancora presente).

#example-box("Esecuzione dell'algoritmo di ripristino")[
  Consideriamo la seguente situazione: 

  #align(center)[
    #image("/assets/11_05_recovery.png", width: 50%)
  ]

  dove $S_0$ è lo stato iniziale del sistema, $S_1$ è il momento in cui viene eseguito un checkpoint, $S_2$ è il momento in cui avviene un crash di sistema. 

  Sappiamo che $T_1$ termina prima che venga effettuato il checkpoint, dunque non subirà modifiche nel momento in cui il sistema verrà ripristinato. Per quanto riguarda tutte le altre transazioni, queste verranno *annullate* tutte, dal momento che sono tutte attive a partire dal checkpoint, tuttavia $T_2$ e $T_3$ avevano completato il commit prima del crash, dunque le loro modifiche devono essere *ripristinate*.
]

Di seguito mostriamo un il flusso operativo per il ripristino dopo un crash in un sistema che utilizza un *checkpoint* di tipo *buffer consistent*. Nel momento in cui si inizia con il ripristino si inizia a scorrere tutto il log in ordine inverso, partendo dall'ultimo record scritto prima del crash. 

Immaginiamo di avere due liste $L_r, L_u$ che conterranno rispettivamente le transazioni che necessitano di un *redo* e quelle che necessitano di un *undo*. A questo punto controlliamo il tipo di ogni record: 

- se il record è di tipo *`(T_i, "commit")`*, allora la transazione $T$ viene aggiunta alla lista $L_r$, ossia, sarà al termine del rollback necessario effettuare un *redo* delle sue modifiche;

- se il record è di tipo *`(T_i, "update")`* allora l'operazione viene *annullata* e la transizione è aggiunta a $L_u$, indicando che sarà  effettuare un *undo* delle sue modifiche;

- se il record è di tipo *`("begin", T_i)`* significa che non dobbiamo più annullare operazioni per una transazione e possiamo rimuovere $T_i$ da $L_u$;

- se il record è di tipo *`("checkpoint", L)`*, dove $L$ è la lista delle transazioni attive al momento del checkpoint, allora possiamo procedere come segue: 

  - per ogni transazione $T_i in L$, se $T_i in.not L_r$ allora aggiungere $T_i$ ad $L_u$
  - a questo punto il rollback continua come sopra fino a quando $L_u$ non è vuota;

- una volta terminato il rollback si può procedere con il *rollforward*: per ogni record a partire dall'ultimo checkpoint fino al crash, si procede con il redo dei record, se il record è di tipo commit allora la transazione $T_i$ è rimossa da $L_r$. Nel momento in cui $L_r$ è vuota, il ripristino è completo.

#figure(
  image("/assets/11_06_full_recovery_example.png", width: 80%)
)