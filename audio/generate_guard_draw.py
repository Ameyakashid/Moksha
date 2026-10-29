"""Original short metallic intake: guard raises a weapon before attacking."""
from pathlib import Path
import math, struct, wave
rate=22050
seconds=0.24
samples=[]
for i in range(round(rate*seconds)):
    t=i/rate
    # Two rising partials and an inharmonic high overtone; no external samples.
    attack=min(1.0,t/0.014)
    release=max(0.0,1-t/seconds)**1.8
    signal=(0.52*math.sin(2*math.pi*(610*t+510*t*t))
            +0.28*math.sin(2*math.pi*(925*t+730*t*t))
            +0.10*math.sin(2*math.pi*2270*t)*math.exp(-18*t))
    samples.append(round(signal*attack*release*21000))
with wave.open(str(Path(__file__).with_name('guard_draw.wav')),'wb') as output:
    output.setparams((1,2,rate,0,'NONE','not compressed'))
    output.writeframes(struct.pack('<'+'h'*len(samples),*samples))
