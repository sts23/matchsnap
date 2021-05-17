# matchsnap

Script zum prüfen ob der letzte Snapshot eines Datasets (Destination) auch auf einem anderem Dataset (Source) vorhanden ist.
So läßt sich z.B. prüfen ob der letzte Snapshot auf einem Replika auf der Quelle vorhanden ist. 
Des Weiteren wird das Alter des Destination Snapshots ermittelt.

Wird ein ein Dataset mit einem Host angegeben wird das Dataset per ssh angesprochen.

## Aufruf:
```  
zfsrasp:~# ./matchsnap.sh

Usage: matchsnap.sh [-hq] [-t tag ] <Destination Dataset> [Source Dataset]

  Check if latest Snapshot on Destination exists on Source.

  -h show help
  -q quietmode. Less output, more machine readable.
  -t <Tag> Look (grep) only for Snapshots with a specific Name.
     Example: -t backup-daily to find only snapshots with backup-daily in its name
```
## Beispiele:
Lokal prüfen ob der letzte Snapshot des backup/sr/smbshr Datasets (Destination) auch auf pool1/smbshr vorhanden ist.
```
zfsrasp:~# ./matchsnap.sh backup/sr/smbshr pool1/smbshr
+ Get last snapshot from target (Name,Guid,Creation): backup/sr/smbshr
  backup/sr/smbshr@backup-zfs_2021-05-08_13:40:44       7450179890112682419       1620474044
+ Age of Snapshot:  5h
+ Get matching snapshots from source (Name,Guid,Creation): pool1/smbshr
  pool1/smbshr@backup-zfs_2021-05-08_13:40:44   7450179890112682419     1620474044
zfsrasp:~#

```
Wird kein Source Dataset angegeben wird mit allen Snapshots der Quelle verglichen.

Datasets können auch mit Host und Port angegeben werden.
Hier wird zum prüfen per ssh auf den Host verbunden.
```
zfsrasp:~# ./matchsnap.sh 127.0.0.1:backup/sr/smbshr 192.168.178.31:22:pool1/smbshr
+ Get last snapshot from target (Name,Guid,Creation): backup/sr/smbshr 127.0.0.1
  backup/sr/smbshr@backup-zfs_2021-05-08_13:40:44       7450179890112682419       1620474044
+ Age of Snapshot:  5h
+ Get matching snapshots from source (Name,Guid,Creation): pool1/smbshr 192.168.178.31
  pool1/smbshr@backup-zfs_2021-05-08_13:40:44   7450179890112682419     1620474044
zfsrasp:~#
```

Mit -q (Quietmode) erhält man eine gekürzte eher Maschinen lesbare Darstellung.
Wird als Dataset "alldatasets" angegeben wird der Vergleich für alle Datasets durchgeführt.
```
zfsrasp:~# ./matchsnap.sh -q 127.0.0.1:alldatasets 192.168.178.31:pool1/smbshr
+ Match:NO D:FOUND S:NOSNP DA:0 DDS:backup SDS:pool1/smbshr T:
+ Match:NO D:FOUND S:NOSNP DA:0 DDS:backup/smbshr SDS:pool1/smbshr T:
+ Match:NO D:NOSNP S:NOSNP DA:-1 DDS:backup/sr SDS:pool1/smbshr T:
+ Match:OK D:FOUND S:FOUND DA:6 DDS:backup/sr/smbshr SDS:pool1/smbshr T:
+ Match:NO D:FOUND S:NOSNP DA:6 DDS:backup/sr/smbshr/smbshr SDS:pool1/smbshr T:
+ Match:NO D:NOSNP S:NOSNP DA:-1 DDS:backup/sr2 SDS:pool1/smbshr T:
+ Match:NO D:FOUND S:NOSNP DA:0 DDS:backup/su SDS:pool1/smbshr T:
...
```
```
Match: OK wenn eine Übereinstimmung gefunden wurde.
D:     FOUND es wurde ein passender Snapshot auf dem Destination Dataset gefunden.
S:     FOUND es wurde ein passender Snapshot auf dem Source Dataset gefunden.
DA:    Alter des Destination Snapshots in Stunden (-1 wenn kein Snapshot gefunden wurde)
DDS:   Destination Dataset 
SDS:   Source Dataset 
T:     Wird die Option -t verwendet wird hier der Filterbegriff angegeben.
```
## cmk_snapcheck
Wrapper-Script für checkmk local checks mit check_mk_agent.
Muss unter /usr/lib/check_mk_agent/local abgelegt werden.

Parameter zum anpssen:
```
## Config Variables
MATCHSNAP="/usr/local/bin/matchsnap.sh"
DESTDS="backup/bsp/shr"
SOURCEDS="192.168.XXX.XXX:pool1/shr"
WARNAGE="24"
CRITAGE="48"
TAG="backup"
```

## Todo
Alles noch Work in progress und nicht final.
