"""Original map architecture. Run with Blender --background --python this_file.

Geometry is batched by material for small draw-call counts. Blender source and
game-ready GLBs are exported together, keeping the art editable and reproducible.
"""
import bpy
import math
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'map_art'
SOURCE = ROOT / 'tools' / 'art_sources'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = .88
    if emission:
        bs.inputs['Emission Color'].default_value = (*color, 1)
        bs.inputs['Emission Strength'].default_value = emission
    return m

rose = material('Rose sandstone', (.49, .19, .25))
sand = material('Honey sandstone', (.64, .36, .16))
trim = material('Carved warm limestone', (.89, .66, .36))
teal = material('Oxidised turquoise copper', (.055, .28, .29))
dark = material('Deep recessed arch', (.025, .018, .04))
gold = material('Brass finials', (.63, .35, .10))
lamp = material('Amber glass', (1, .24, .035), 2.0)
blue = material('Turquoise glass', (.07, .65, .65), 2)

class Builder:
    def __init__(self): self.parts = defaultdict(lambda: [[], []])
    def poly(self, vertices, faces, mat):
        v, f = self.parts[mat]
        offset = len(v)
        v.extend(vertices)
        f.extend(tuple(offset+i for i in face) for face in faces)
    def box(self, c, size, mat):
        x,y,z=c; a,b,h=[s/2 for s in size]
        self.poly([(x-a,y-b,z-h),(x+a,y-b,z-h),(x+a,y+b,z-h),(x-a,y+b,z-h),
                   (x-a,y-b,z+h),(x+a,y-b,z+h),(x+a,y+b,z+h),(x-a,y+b,z+h)],
                  [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat)
    def lathe(self, x,y,z, rings, mat, n=20):
        v=[(x+r*math.cos(i*math.tau/n),y+r*math.sin(i*math.tau/n),z+h)
           for r,h in rings for i in range(n)]
        f=[]
        for j in range(len(rings)-1):
            for i in range(n):
                a=j*n+i; b=j*n+(i+1)%n
                f.append((a,b,b+n,a+n))
        f.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*n+i for i in range(n))])
        self.poly(v,f,mat)
    def arch(self,x,y,z,w,h,depth,mat, axis=0):
        # Actual opening, with an elliptical vault and radial carved stones.
        r=w/2; spring=h-r*.85; thick=.32
        def tr(a,b,c): return (x+a,y+b,z+c) if axis==0 else (x+b,y+a,z+c)
        for side in [-1,1]:
            c=tr(side*(r+thick/2),0,spring/2)
            size=(thick,depth,spring) if axis==0 else (depth,thick,spring)
            self.box(c,size,mat)
        for i in range(14):
            a=i*math.pi/14; b=(i+1)*math.pi/14
            vv=[]
            for dep in [-depth/2,depth/2]:
                for rad,t in [(r,a),(r,b),(r+thick,b),(r+thick,a)]:
                    vv.append(tr(rad*math.cos(t),dep,spring+rad*.85*math.sin(t)))
            self.poly(vv,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat)
    def window(self,x,y,z,w,h,lit=True):
        self.box((x,y,z+h*.43),(w,.10,h*.86),dark)
        self.arch(x,y-.12,z,w,h,.20,trim)
        self.box((x,y-.08,z+h*.36),(w*.66,.12,h*.64),lamp if lit else teal)
        for dx in [-.21,.21]: self.box((x+dx*w,y-.18,z+h*.35),(.065,.12,h*.70),gold)
        self.box((x,y-.18,z+h*.38),(w,.12,.08),gold)
        self.box((x,y-.45,z-.12),(w+1,.9,.22),trim)
    def pavilion(self,x,y,z,r,mat):
        self.box((x,y,z+.2),(r*2.5,r*2.5,.4),trim)
        h=r*1.8
        for axis in [0,1]:
            for sign in [-1,1]:
                self.arch(x if axis==0 else x+sign*r,y+sign*r if axis==0 else y,z+.4,r*1.55,h,.28,mat,axis)
        self.box((x,y,z+h+.7),(r*2.7,r*2.7,.3),trim)
        self.lathe(x,y,z+h+.85,[(r*1.35,0),(r*1.1,.25),(r,.5),(r*.85,r*.65),(r*.45,r*1.1),(r*.08,r*1.35)],teal)
        self.lathe(x,y,z+h+r*1.35+.85,[(.12,0),(.12,.6),(.25,.75),(.0,1.05)],gold,10)
    def export(self,name):
        bpy.ops.object.select_all(action='DESELECT')
        col=bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
        for mat,(verts,faces) in self.parts.items():
            mesh=bpy.data.meshes.new(name+' '+mat.name)
            mesh.from_pydata(verts,[],faces)
            mesh.materials.append(mat)
            mesh.update()
            obj=bpy.data.objects.new(mesh.name,mesh)
            col.objects.link(obj)
            obj.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True)
        for obj in col.objects: obj.hide_set(True)

def palace(name,wall):
    b=Builder()
    # Asymmetric terraced wings, a tall western observatory and open roof pavilions.
    b.box((0,0,1),(76,29,2),trim)
    for x,width,height in [(-26,20,17),(-6,20,25),(14,20,20),(30,12,13)]:
        b.box((x,0,height/2+2),(width,22,height),wall)
        for z in range(3,int(height)+3,5):
            b.box((x,-.1,z),(width+1,23,.35),trim)
            for wx in range(int(x-width/2)+2,int(x+width/2)-1,4):
                b.window(wx,-11.2,z+.7,1.55,2.8,((wx+z)%3)!=0)
        b.box((x,0,height+2),(width+2,24,.5),trim)
        for xx in range(int(x-width/2),int(x+width/2)+1,2):
            b.box((xx,-11.5,height+2.8),(.7,.65,1.4),wall)
        b.pavilion(x,0,height+2.4,2.7,wall)
    # Wide stepped ghats and a pierced entrance colonnade.
    for i in range(7): b.box((0,-18-i*.95,.15+i*.15),(42+i*3,1.8,.3+i*.3),wall)
    for x in range(-32,35,6): b.arch(x,-13,2,4.2,5.4,1.3,wall)
    b.box((0,-13,7.8),(75,3,.6),trim)
    b.pavilion(-27,0,23,4,wall)
    b.export(name)

day_trim, day_teal = trim, teal
trim = material('Moonlit brass limestone', (.48,.32,.20))
teal = material('Night patinated domes', (.045,.12,.13))
palace('moon_palace',rose)
trim, teal = day_trim, day_teal
palace('desert_observatory',sand)
b=Builder()
for x in [-7,7]:
    b.box((x,0,4),(4,4,8),sand)
    b.pavilion(x,0,8,2.2,sand)
b.arch(0,0,0,9,10,3,sand)
b.box((0,0,10.4),(20,4.5,.7),trim)
for x in [-7,7]:
    for z in [1,4]: b.window(x,-2.1,z,1.3,2.2,False)
b.export('caravan_gate')
b=Builder()
b.pavilion(0,0,0,3.0,sand)
b.export('oasis_pavilion')
b=Builder()
b.lathe(0,0,0,[(.32,0),(.45,.15),(.45,.25),(.30,.4)],gold,8)
b.lathe(0,0,1.15,[(.30,0),(.48,.15),(.35,.30),(.02,.60)],gold,8)
b.lathe(0,0,.42,[(.26,0),(.26,.70)],lamp,8)
for i in range(8):
    a=i*math.tau/8
    b.box((.29*math.cos(a),.29*math.sin(a),.77),(.045,.045,.8),gold)
b.export('brass_lantern')
b=Builder()
# A playable roof with no tall geometry in the forward (-Godot Z) view.
b.box((0,0,5),(22,26,10),sand)
b.box((0,0,9.85),(22.7,26.7,.30),trim)
b.box((0,0,10),(21.5,25.5,.10),sand)
for x in [-10.7,10.7]:
    b.box((x,0,10.48),(.6,26,.95),sand)
    b.box((x,0,11.0),(.85,26.4,.12),trim)
for y,h in [(-12.7,1.0),(12.7,.65)]:
    b.box((0,y,10+h/2),(21.7,.55,h),sand)
    b.box((0,y,10+h),(22,.75,.12),trim)
for x in [-7.9,7.9]: b.pavilion(x,-9.5,10,1.8,sand)
for y in [-13.05,13.05]:
    for x in [-8,-4,0,4,8]:
        for z in [1.4,5.4]: b.window(x,y,z,1.5,2.6,False)
for x in range(-9,10,3): b.box((x,0,10.06),(.035,24,.018),trim)
for y in range(-12,13,3): b.box((0,y,10.06),(20,.035,.018),trim)
b.export('flight_terrace')
library_scene = bpy.context.scene
for collection in list(library_scene.collection.children):
    if not collection.objects:
        continue
    scene = bpy.data.scenes.new(collection.name)
    scene.collection.children.link(collection)
    for obj in collection.objects:
        obj.hide_set(False)
bpy.context.window.scene = bpy.data.scenes['moon_palace']
bpy.data.scenes.remove(library_scene)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'rajasthan_landmarks.blend'))
print('MAP ART COMPLETE')
