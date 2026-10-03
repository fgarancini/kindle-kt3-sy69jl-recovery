# Recuperar un Kindle básico 8ª gen (SY69JL / KT3) colgado en el logo "árbol con el nene"

Guía basada en un caso real (octubre 2026). Un Kindle de 10 años quedó **congelado en la pantalla de arranque** (logo "kindle" arriba y el dibujo del árbol con el nene abajo), no lo detectaba la PC y ningún reinicio lo arreglaba. Se recuperó completo desde Windows 10, sin soldar nada, y después se le hizo jailbreak.

> **Léela entera antes de empezar.** Esto flashea el bootloader y el sistema del Kindle con herramientas y archivos de terceros. Si tu equipo todavía funciona, no lo hagas. Si ya está inutilizable, el riesgo es bajo. Nadie garantiza que funcione en tu caso.

English: [README.md](README.md)

## Contenido del repositorio

| Ruta | Qué es |
|---|---|
| `patches/0001-build-with-modern-gcc.patch` | Arreglos para compilar el u-boot de MollySophia con un GCC moderno (aplica sobre `cc580e3` del repo original). |
| `patches/0002-fastboot-long-press-threshold-600s.patch` | Sube la ventana de pulsación larga para fastboot de 15 s a 600 s. |
| `scripts/get_toolchain.sh` | Descarga el GCC ARM 10.3 portable usado para compilar. |
| `scripts/build_uboot.sh` | Clona el u-boot original, aplica los parches y compila `u-boot.imx` (con `THRESHOLD=1` aplica también el 0002). |
| `scripts/fix_fastboot_guid.ps1` | Windows (administrador): fija el GUID de interfaz de Android para que el `fastboot.exe` de Google vea el equipo. |
| Releases → `u-boot-threshold600.imx` | El binario que se cargó en el Kindle (ver las notas de la release). |

---

## 0. Resumen en 10 líneas

1. Probá **otro cable USB** (con datos). En este caso el primer cable no transmitía datos y por eso la PC "no detectaba nada".
2. Con un buen cable, el Kindle aparece en Windows como **`VID_15A2 & PID_0063`** = procesador **i.MX6SL** en *Serial Download Mode* (SDP). Eso significa que el procesador está vivo y se puede recuperar por USB.
3. No era la batería ni había que tocar ninguna "BIOS" (los Kindle no tienen).
4. Se carga por USB un **u-boot con fastboot** (el de MollySophia, **recompilado con el umbral de pulsación larga subido**).
5. Con fastboot se flashea un **bootloader** y las particiones del **firmware original** (paquete CracKdroid `kindle8.230118.zip`).
6. El sistema arranca pero la pantalla de inicio queda en blanco: se arregla con un archivo vacío **`DO_FACTORY_RESTORE`** en la raíz.
7. Aparece el asistente de configuración y el Kindle queda funcionando.
8. Opcional: jailbreak **KindleBreak** (firmware 5.12.2) + Hotfix + KUAL. KUAL no abría hasta que se escribió **`;log mrpi`** en la barra de búsqueda.
9. Los `.epub` **no** se abren en este firmware: convertir a `.azw3` con Calibre.
10. Tiempo total real: varias horas, la mayoría esperando ventanas de fastboot de pocos segundos.

---

## 1. El equipo y los síntomas

| Dato | Valor |
|---|---|
| Modelo | **SY69JL** = Kindle básico 8ª generación (2016), 6", táctil. En la comunidad se lo llama **KT3** |
| Síntoma | Congelado en el logo de arranque (kindle + árbol con el nene) |
| PC | No lo detectaba como unidad ni como nada |
| Reinicio forzado (40 s) y carga | No servían |
| Firmware instalado luego | Kindle 5.12.2 |

---

## 2. Qué NO era (descartado)

- **Batería:** se sospechó primero. Con un cable en buen estado el procesador enumeraba por USB, así que había energía suficiente. La batería sigue siendo vieja (repuesto compatible: **58-000083**, 890 mAh), pero no era la causa del cuelgue.
- **"Flash de BIOS":** no existe en un Kindle. Lo equivalente es flashear bootloader/particiones por USB, que es lo que se hizo.
- **Jailbreak para arreglarlo:** el jailbreak requiere un sistema que arranque. Va *después*.

---

## 3. Diagnóstico: primero el cable

Probá **dos o tres cables y puertos distintos**. Algunos cables solo cargan.

Con un cable bueno, en el Administrador de dispositivos (o con PowerShell) apareció:

```powershell
Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like 'USB\VID*' }
# -> USB Input Device   USB\VID_15A2&PID_0063\...
```

`15A2` es NXP/Freescale y `0063` corresponde a **i.MX6SL en modo de descarga (SDP)**. Se confirma con `uuu`:

```
uuu.exe -lsusb      ->   MX6SL  SDP:  0x15A2  0x0063
```

Si ves eso, el procesador está bien y el problema está en el bootloader/almacenamiento: es recuperable.

---

## 4. Herramientas y archivos usados

- **Windows 10** (Home sirve), PowerShell.
- **uuu (NXP Universal Update Utility)** – `uuu.exe` de https://github.com/nxp-imx/mfgtools/releases (se usó la 1.5.243). Reconoció el MX6SL sin instalar drivers extra.
- **platform-tools de Google** (`fastboot.exe`).
- **Driver USB de Google** (`usb_driver_r13-windows.zip`, trae `android_winusb.inf`).
- **Zadig** (para instalar WinUSB al dispositivo de fastboot del primer u-boot).
- **WSL con Ubuntu** y un compilador ARM portable (`gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf`) para compilar u-boot.
- **u-boot de MollySophia:** https://github.com/MollySophia/imx6_android_u-boot_kindle
- **Paquete CracKdroid** `kindle8.230118.zip` (de https://github.com/Ooonana/Guide-to-installing-android-on-kindle, sección *Releases*). Trae `restore.img`, `userdata.bin`, `diagsys.bin`, `diagkern.bin`, `kernel.bin`, `system.bin` (firmware original de 2019) y un script `fastdownload.bat`. El sitio original (kdroid.club) y el canal de Telegram ya no existen.
- **Calibre** (para convertir libros).

### Aviso sobre antivirus
Windows Defender marcó el zip como **`Trojan:Script/Phonzy.A!ml`** (detección heurística por aprendizaje automático; sospecho que es falso positivo por los `.bat` en chino, pero **no lo puedo garantizar**). Se leyó el script completo antes de usarlo: solo usa `fastboot` y `adb` y no toca nada fuera de su carpeta. El ejecutable `fastdownload.exe` es **cerrado y sin firma**. Si te incomoda, hacelo en una PC secundaria.
Para trabajar se creó **una carpeta con exclusión de Defender** (y se quitó al final). No dejes exclusiones permanentes.

---

## 5. Paso a paso

### 5.1 Compilar el u-boot con el umbral subido

En ese u-boot el fastboot por botón se activa con **dos pulsaciones largas dentro de `LP_FASTBOOT_THRESHOLD` segundos** (aquí "LP" = *long press*, no *low power*). Por defecto son 15 s, imposible de cumplir al cargar por USB. Se sube a 600:

```
board/freescale/mx6sl_heisenberg/pmic_rohm.c
#define LP_FASTBOOT_THRESHOLD   600
```

Ese u-boot es de 2013 y no compila tal cual con GCC moderno. Hubo que:

```bash
# 1) falta la cabecera para la versión del compilador
cp include/linux/compiler-gcc4.h include/linux/compiler-gcc10.h   # (y 5..13)

# 2) "extern inline" en cabeceras -> static inline
grep -rl '^extern inline' --include=*.h . | xargs sed -i 's/^extern inline/static inline/'

# 3) funciones "__algo" con alias débil declaradas inline -> sacar el inline
grep -rlE '^(void|int|ulong|unsigned long) +inline +__' --include=*.c common drivers lib net fs disk arch/arm board/freescale api \
  | xargs sed -i -E 's/^(void|int|ulong|unsigned long) +inline +__/\1 __/'
grep -rlE '^inline +[a-z_ ]+ +__' --include=*.c common drivers lib net fs disk arch/arm board/freescale api \
  | xargs sed -i -E 's/^inline +([a-z_ ]+ +__)/\1/'

# compilar
export PATH=/ruta/gcc-arm-10.3.../bin:$PATH
make ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabihf- mx6sl_heisenberg_config
make ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabihf-
# resultado: u-boot.imx (~360 KB)
```

(El `apt` de esa distro WSL estaba roto; se evitó instalando el compilador portable en una carpeta aparte.)

### 5.2 Entrar en fastboot desde el modo Freescale

Cada carga con `uuu` **no sirvió dos veces seguidas**. Lo que funcionó:

1. Reinicio forzado (**botón de encendido 40 s**) con el cable conectado. *(Los 40 s son solo para este paso de cargar el u-boot por SDP; en el paso de flashear, ver 5.4, el procedimiento es otro.)*
2. `uuu.exe SDP: boot -f u-boot-threshold600.imx` → **primera carga** (puede tardar ~30 s; con cable bueno a veces 8 s).
3. Otro reinicio forzado de 40 s.
4. **Segunda carga** con el mismo comando (dentro de los 10 minutos).
5. Aparece un dispositivo **`VID_1949 & PID_D0D0`** (fastboot).

### 5.3 Driver para el fastboot

El primer dispositivo (`1949:D0D0`) quedó "en Error". Se instaló **WinUSB con Zadig**. Pero el `fastboot.exe` de Google busca el GUID de interfaz de Android, no el que pone Zadig, así que **no lo veía**. Se corrigió cambiando en el registro (como administrador):

```
HKLM\SYSTEM\CurrentControlSet\Enum\USB\VID_1949&PID_D0D0\<serie>\Device Parameters
DeviceInterfaceGUIDs = {F72FE0D4-CBCB-407D-8814-9ED673D0DD6B}
```

Después `fastboot devices` lista el equipo.

> **Ojo con el cable:** con el primer cable el fastboot enumeraba pero las escrituras fallaban con `AdbWriteEndpointSync failed ... semaphore timeout`. Con otro cable respondió al instante.

### 5.4 Flashear

```
fastboot flash bootloader restore.img      # bootloader del paquete (208 KB)
fastboot reboot
```

Tras eso el Kindle mostró **una vez** la pantalla oficial *"Es necesario reparar el Kindle ... J5_ROOTFS_REPARTITIONING"* y se vio como unidad USB: el bootloader nuevo funcionaba.

> **Esta fase NO es "mantené el botón 40 s y funciona".** Después de flashear `restore.img`, el Kindle solo expone fastboot durante **~8 segundos en cada arranque**, y cada ventana acepta **un solo comando**. La clave fue **mantener el aparato en reinicio constante** (en este caso se forzaron los reinicios con el botón de encendido) mientras **un script ya corriendo y consultando el USB** atrapaba la ventana y lanzaba un `fastboot flash` antes de que se cerrara. Varios intentos fallaron a mitad de la transferencia y hubo que repetirlos en la ventana siguiente. En la práctica: un script que espera el dispositivo y ejecuta *un* comando, y vos manteniendo el equipo reiniciando.

Con el sistema todavía roto, el bootloader nuevo **abre una ventana de fastboot de ~8 s en cada arranque** (`VID_18D1 & PID_4E40`, "Android Bootloader Interface"). Para que Windows lo reconozca se instaló el driver oficial de Google (como administrador):

```
pnputil /add-driver android_winusb.inf /install
```

Y se flasheó **un comando por ventana** (se automatizó con un script que esperaba la ventana y lanzaba el comando):

```
fastboot flash userdata     userdata.bin     # 64 MB
fastboot flash diags        diagsys.bin      # 64 MB
fastboot flash diags_kernel diagkern.bin     # 8 MB
fastboot flash kernel       kernel.bin       # 5 MB
fastboot flash system       system.bin       # 460 MB (~2 min de envío + 20 s de escritura)
```

Algunos intentos fallaron porque la ventana se cerraba a mitad; se reintentó hasta completar.

Notas sobre `fastdownload.exe` (el flasheador del paquete):
- Escribe `cache` (con `data.bin`), `kernel` y `system`, pero **se cuelga** si la ventana se cierra, usando 100 % de CPU. Por eso se hizo a mano con `fastboot`.
- `config.bin` (contiene `newkindle8`) **no es una partición** (`flash config` da `partition does not exist`). Probablemente solo verifica el tipo de equipo; es una suposición.

### 5.5 Cuando el sistema ya arranca: la "doble pulsación"

Una vez que el sistema arranca, **ya no aparece la ventana de fastboot sola**. Para volver, hay que hacer **dos pulsaciones largas** del botón de encendido:

1. Mantener ~10 s hasta que reinicie, soltar.
2. **Apenas aparezca el logo con el árbol**, volver a mantener ~10 s, soltar.

La ventana se abre ~20 s después. Si la segunda pulsación llega cuando ya cargó el sistema, no funciona.

### 5.6 Pantalla de inicio en blanco → `DO_FACTORY_RESTORE`

El sistema arrancaba (bloqueo, menú de energía, Wi-Fi, teclado funcionaban) pero **la pantalla de inicio nunca se dibujaba**. Solución, de un hilo de MobileRead:

1. Conectar el Kindle por USB.
2. Crear un **archivo vacío llamado `DO_FACTORY_RESTORE`** en la raíz (junto a `documents`).
3. Expulsar, desenchufar y reiniciar.

Resultado: apareció el **asistente de configuración** (selección de idioma) y todo funcionó. Había además un `update.bin.tmp.partial` de 0 bytes en la raíz: el Kindle había intentado bajar una actualización obligatoria sin recibir datos.

---

## 6. Jailbreak (opcional)

Firmware **5.12.2** + KT3 → compatible con **KindleBreak** (soporta 5.10.3 a 5.13.3; **no** funciona en la 5.12.2.2). Se hace **sin Wi-Fi**.

1. Activar **modo avión** y mantenerlo.
2. Bajar de https://kindlemodding.org/jailbreaking/Legacy/KindleBreak/ los archivos `jb-kindlebreak.zip` (MD5 `0215c36cc1e3ad8136a67daebe369452`) y `file__0.localstorage`.
3. Descomprimir el zip en la raíz del Kindle y copiar `file__0.localstorage` a `/.active_content_sandbox/browser/resource/LocalStorage/`.
4. Expulsar, abrir el **Navegador Experimental**; el equipo se congela, se reinicia solo (aparece "Kindle Feedback") y queda con el jailbreak.
5. Verificar: aparece `kindlebreak_log.txt` en la raíz con `Created developer key (0)` y los archivos del exploit se borraron solos.

**Hotfix:** copiar `Update_hotfix_universal.bin` (https://github.com/KindleModding/Hotfix/releases) a la raíz → *Ajustes → ⋮ → Actualizar el Kindle* → luego abrir el ítem **"Run Hotfix"** de la biblioteca.

**KUAL (funcionó, pero hay un paso que es fácil olvidar):** se copiaron `KUAL.sh` y `KUAL.jar` (PEKI) a `documents` y las carpetas `extensions` y `mrpackages` (MRPI) a la raíz. `KUAL.sh` se instaló (el `.jar` se borró solo, es normal), pero al abrirlo mostraba "Abriendo…", la portada se ponía negra y volvía a la biblioteca, incluso después de reiniciar.

**Solución:** en la **barra de búsqueda** de la biblioteca escribir exactamente **`;log mrpi`** y tocar buscar. Aparece un mensaje ("Hush little baby…") con íconos parpadeando, la pantalla parpadea y vuelve a la biblioteca. Después de eso **KUAL abrió bien**. Es el paso que la guía de instalación da por sabido y en este caso no se hizo hasta el final. (No está confirmado si fue exactamente ese comando lo que lo arregló o si ayudó el tiempo transcurrido; pero fue lo último que se cambió antes de que funcionara.)

Con KUAL funcionando ya se puede **bloquear las actualizaciones automáticas** (extensión *Rename OTA Binaries* → *Rename*) e instalar KOReader.

**Para conservar el jailbreak** conviene dejar el modo avión: si se conecta a Wi-Fi puede actualizarse solo.

---

## 7. Cargar libros

Este firmware **no abre `.epub`**. Convertir con Calibre:

```
ebook-convert "libro.epub" "libro.azw3"
```

Copiar el `.azw3` (o `.mobi`) a `documents`. Los `.pdf` abren directo.

---

## 8. Lecciones y trampas

- **El cable fue clave dos veces** (detección y escrituras USB). Probá varios.
- **Cada comando de fastboot necesita su propia ventana (~8 s)**: automatizá con un script que espere el dispositivo y mantené el aparato reiniciando hasta que lo atrape. El tiempo lo es todo.
- **Un reinicio forzado de 40 s entre cargas de u-boot** fue necesario; sin él la segunda carga fallaba con `LIBUSB_ERROR_IO`.
- **No ejecutes nada que no leíste.** Aquí se revisó `fastdownload.bat`, `jb.sh` y `rename.sh`; los `.exe` cerrados no se pudieron auditar.
- La hipótesis inicial (batería) era **incorrecta**: no te quedes con la primera explicación.
- Con un equipo roto y sin nada que perder el riesgo es bajo. Si todavía funciona, no lo toques.

---

## 9. Lo que no sé / no se verificó

- Por qué el primer arranque con el bootloader nuevo mostró la pantalla de reparación y los siguientes no.
- Por qué la pantalla de inicio quedó en blanco antes del `DO_FACTORY_RESTORE` (se sospechó falta de algún componente; la causa real no se confirmó).
- Si fue exactamente `;log mrpi` lo que arregló KUAL (ver sección 6); es lo último que se cambió antes de que abriera.
- Si otros SY69JL con la misma falla responden igual. Un solo caso.

---

## 10. Referencias

- MobileRead – KT3 Debricking: https://www.mobileread.com/forums/showthread.php?t=355003
- MobileRead – KT3 demo mode / `DO_FACTORY_RESTORE`: https://www.mobileread.com/forums/showthread.php?t=345733
- MobileRead – KT2 `imx_usb` caso similar: https://www.mobileread.com/forums/showthread.php?t=350510
- u-boot Kindle KT3 (MollySophia): https://github.com/MollySophia/imx6_android_u-boot_kindle
- Paquete CracKdroid / guía: https://github.com/Ooonana/Guide-to-installing-android-on-kindle
- uuu (NXP): https://github.com/nxp-imx/mfgtools
- KindleModding (jailbreak): https://kindlemodding.org/jailbreaking/
- KindleBreak: https://www.mobileread.com/forums/showthread.php?t=338268
