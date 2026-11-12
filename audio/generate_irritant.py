"""Original deterministic two-note warning and short filtered air-release cue.
No samples, borrowed melodies, or third-party audio inputs.
"""
import math, random, struct, wave
from pathlib import Path
RATE=22050
rng=random.Random(731)
for kind, seconds in [('warning', .24), ('hiss', .30)]:
    samples=[]; previous=0.0
    for i in range(int(RATE*seconds)):
        t=i/RATE
        envelope=min(1,t/.015)*min(1,(seconds-t)/.05)
        if kind=='warning':
            hz=740 if t<.10 else 990
            value=.25*math.sin(2*math.pi*hz*t) if t<.09 or t>.13 else 0
        else:
            noise=rng.uniform(-1,1)
            value=.22*(noise-previous);previous=noise
        samples.append(struct.pack('<h',int(max(-1,min(1,value*envelope))*32767)))
    with wave.open(str(Path(__file__).with_name('irritant_'+kind+'.wav')),'wb') as f:
        f.setparams((1,2,RATE,0,'NONE','not compressed'));f.writeframes(b''.join(samples))
