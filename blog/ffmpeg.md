$ arecord -L
...
sysdefault:CARD=P3251
    Plantronics Blackwire 325.1, USB Audio
    Default Audio Device
...
$ sudo ffmpeg -f alsa -i sysdefault:CARD=U0x46d0x81b -t 30 out.wav

$ sudo ffmpeg \
    -re \
    -hwaccel cuvid \
\
    -f v4l2 -i /dev/video0 \
    -f alsa -i default \
\
    -c:v h264_nvenc -r 10 -s 640x480 -b:v 32K \
    -c:a aac -b:a 8K \
\
    -f mpegts udp://10.10.2.111:18841/


$ ffmpeg \
    -re \
\
    -f lavfi -i testsrc=duration=999999:size=960x720:rate=25 \
    -vf "drawtext=text=hello%{n}" \
\
    -c:v h264_nvenc \
\
    -f mpegts udp://localhost:8844/

$ ffmpeg \
    ...
    -f rtsp -rtsp_transport udp rtsp://localhost:8842/cam1.sdp
