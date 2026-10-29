# Message schema

| Type | ID | Direction | Payload |
|---|---|---|---|
| HELLO | 1 | Mac → phone | magic, version, token, client info |
| WELCOME | 2 | phone → Mac | version, device, width, height, rotation |
| START | 3 | Mac → phone | — |
| READY | 4 | phone → Mac | — |
| VIDEO_CONFIG | 5 | phone → Mac | SPS/PPS |
| VIDEO_FRAME | 6 | phone → Mac | flags, pts, data |
| TOUCH | 7 | Mac → phone | action, x, y, pointer |
| KEY | 8 | Mac → phone | keycode, action |
| TEXT | 9 | Mac → phone | UTF-8 |
| SCROLL | 10 | Mac → phone | dx, dy |
| GLOBAL | 11 | Mac → phone | action |
| PING | 12 | both | — |
| PONG | 13 | both | — |
| ORIENTATION | 14 | phone → Mac | rotation |
| ERROR | 15 | both | code, message |
