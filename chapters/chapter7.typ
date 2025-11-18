
#import "@preview/theorion:0.4.0": *
#import cosmos.fancy: *
#show: show-theorion
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#show: codly-init.with()
#import "../lib.typ": *

= Architetture per Basi di Dati
Questo capitolo dà inizio alla seconda parte del corso. Tutto ciò che tratteremo da questo momento in poi supporrà che il punto di partenza sia quello di un *java relational system*. La struttura di base di tale elemento è quella che è già stata presentata in @fig:rdbms_internal, che per completezza viene di seguito riportata.


#image("../images/ch03/rdbms_internal.png", width: 75%)


La scelta di considerare questa architettura viene fatta per semplicità, e per la maggiore familiarità che si ha tipicamente con una base di dati relazionale. Tuttavia, è importante considerare che la maggioranza delle famiglie di database già presentate condivide la gran parte delle componenti con questa architettura.

Come già menzionato l'architettura presentata può essere rappresentata in *due blocchi*

- un blocco che presenta delle componenti specifiche alla famiglia di database che abbiamo scelto di utilizzare, che in questo caso è il *relational engine*
- un blocco che è deputato alla gestione della memorizzazione e il recupero dei dati in memoria principale, a cui ci si riferisce tipicamente con il nome di *storage engine*

Questo schema a blocchi non è sempre presente, esistono casi in cui lo storage engine viene fuso alla componente che normalmente dovrebbe essere più specifica al tipo di dati che vogliamo rappresentare nella nostra base di dati.

In linea di massima però relational (o document database, ...) e storage engine sono tra loro _indipendenti_. Questo maggiore livello di astrazione ci consente di trattare in maniera separata il modo in cui vengono rappresentati a livello logico i dati dal modo in cui questi vengono effettivamente trattati all'interno della memoria secondaria.
