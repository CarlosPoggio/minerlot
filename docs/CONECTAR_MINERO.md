# Cómo conectar un Bitaxe (u otro minero) a esta pool

Esta pool ya está funcionando en el servidor `minerlot-node` (192.168.1.2).
Esto es lo que hay que configurar en cada dispositivo Bitaxe para que
empiece a minar contra ella.

## Datos de conexión

En el panel de configuración del Bitaxe (normalmente se accede escribiendo
su propia IP en el navegador), hay que poner:

- **URL / dirección del pool**: `stratum+tcp://192.168.1.2:3333`
- **Usuario (worker)**: tu dirección de Bitcoin, seguida de un punto y un
  nombre para identificar ese Bitaxe en concreto. Por ejemplo:
  ```
  bc1qv820jhzkrluuhppldtnfr43w3zrdpdnayy537p.bitaxe1
  ```
  Si conectás más de un Bitaxe, cambiá solo la parte de después del punto
  en cada uno (`.bitaxe1`, `.bitaxe2`, etc.) para poder distinguirlos —
  la dirección de antes del punto es siempre la misma, la tuya.
- **Contraseña**: no se usa para nada, podés poner cualquier cosa (por
  ejemplo, `x`).

## Por qué el usuario es tu dirección de Bitcoin

Esta pool no guarda ni gestiona ningún dinero. Cada Bitaxe le dice, en el
momento de conectarse, a qué dirección hay que mandar la recompensa si
ese dispositivo en concreto encuentra un bloque. Por eso es tan importante
escribir bien la dirección: si la escribís mal, la recompensa (si alguna
vez aparece) iría a la dirección equivocada, no a la tuya.

## Cómo saber si está funcionando

Con el Bitaxe conectado, podés comprobar el estado general de la pool
abriendo esto en cualquier navegador de la misma red de casa:

```
http://192.168.1.2:3334/api/info
```

Vas a ver un texto con datos técnicos (no es bonito, es solo información
en bruto) — mientras no dé un error, la pool está viva.

## Importante: el nodo todavía se está poniendo al día

Antes de que la pool pueda validar bloques de verdad, el nodo de Bitcoin
tiene que terminar de descargar y comprobar toda la historia de la
cadena de bloques desde el principio. Esto se hace una sola vez, pero
tarda bastante (varias horas, no minutos). El Bitaxe se puede conectar y
dejar minando desde ya — no hace falta esperar — pero hasta que el nodo
no termine de ponerse al día, no va a poder encontrar bloques válidos de
verdad.

## Si algo no conecta

- Revisá que el Bitaxe esté en la misma red de casa que el servidor (mismo
  router).
- Revisá que escribiste bien la IP (`192.168.1.2`) y el puerto (`3333`).
- Si nada de esto funciona, avisale a Claude en la próxima sesión — con
  este archivo y `docs/PROJECT_STATE.md` tiene todo el contexto para
  investigar sin que tengas que volver a explicar nada.
