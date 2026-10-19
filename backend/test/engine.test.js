import test from 'node:test';
import assert from 'node:assert/strict';
import { COLORS, SAFE, FINISH, newState, act, square, legalMoves, botAction } from '../src/engine.js';
const players = [{ id: 'a', name: 'Alice' }, { id: 'b', name: 'Bob' }];
const roll = (s, n, now = 1) => act(s, s.players[s.turn].id, { type: 'roll' }, now, () => n);
const move = (s, token = 0, now = 2) => act(s, s.players[s.turn].id, { type: 'move', token }, now);
test('2 players use opposite colors; 4 players use all colors', () => {
  assert.deepEqual(newState(players).players.map(p=>p.color), ['red','yellow']);
  assert.equal(newState([...players,{id:'c'},{id:'d'}]).players.length,4);
  assert.throws(()=>newState([players[0]]));
});
test('base needs six and a move is required before another roll', () => {
  let s = newState(players,0); const original=structuredClone(s);
  assert.equal(roll(s,3).turn,1); s=roll(s,6);
  assert.throws(()=>roll(s,6));s=move(s);assert.equal(s.players[0].tokens[0],0);assert.equal(s.turn,0);
  assert.deepEqual(original,newState(players,0));
});
test('three consecutive sixes lose the turn',()=>{
  let s=newState(players,0);s=move(roll(s,6));s=move(roll(s,6));s=roll(s,6);
  assert.equal(s.turn,1);assert.equal(s.players[0].tokens[0],6);assert.equal(s.phase,'roll');
});
test('capture returns opponent to base and grants extra roll',()=>{
  let s=newState(players,0);s.players[0].tokens[0]=26;s.players[1].tokens[0]=1;
  s=move(roll(s,1));assert.equal(s.players[1].tokens[0],-1);assert.equal(s.turn,0);
});
test('safe spots protect opponents',()=>{
  let s=newState(players,0);s.players[0].tokens[0]=25;s.players[1].tokens[0]=0;
  s=move(roll(s,1));assert.equal(s.players[1].tokens[0],0);assert.equal(s.turn,1);
});
test('home needs exact roll; finished pieces cannot move',()=>{
  let s=newState(players,0);s.players[0].tokens=[56,57,57,57];
  assert.equal(roll(s,2).turn,1);s=move(roll(s,1));assert.equal(s.status,'completed');assert.equal(s.winner,'a');
  assert.throws(()=>roll(s,1));assert.equal(square(s.players[0],52),null);
});
test('rejects forged token, foreign player, expired action, premature timeout',()=>{
  const s=newState(players,0);
  assert.throws(()=>act(s,'b',{type:'roll'},1));assert.throws(()=>act(s,'intruder',{type:'forfeit'},1));
  assert.throws(()=>act(s,'a',{type:'roll'},30001));assert.throws(()=>act(s,'a',{type:'timeout'},1));
  assert.throws(()=>act(roll(s,6),'a',{type:'move',token:4},2));
});
test('forfeit skips eliminated players and awards last remaining player',()=>{
  let s=newState([...players,{id:'c'},{id:'d'}],0);
  s=act(s,'b',{type:'forfeit'},1);s=act(s,'a',{type:'forfeit'},1);assert.equal(s.turn,2);
  s=act(s,'c',{type:'forfeit'},1);assert.equal(s.winner,'d');assert.equal(s.status,'completed');
});
test('three missed turns automatically forfeit an absent player',()=>{
  let s=newState(players,0);
  for(let i=0;i<3;i++){
    s=act(s,'a',{type:'timeout'},s.deadline);
    if(s.status==='active')s=roll(s,1,s.deadline-1);
  }
  assert.equal(s.winner,'b');
});
test('bots can finish complete 2- and 4-player games while preserving invariants',()=>{
  for(const count of [2,4]){
    let s=newState(Array.from({length:count},(_,i)=>({id:`bot:${i}`})),Date.now());let n=0;
    while(s.status==='active'&&n++<20000){s=act(s,s.players[s.turn].id,botAction(s),Date.now());for(const p of s.players)assert.ok(p.tokens.every(t=>Number.isInteger(t)&&t>=-1&&t<=57));}
    assert.equal(s.status,'completed');assert.ok(s.players.find(p=>p.id===s.winner).tokens.every(t=>t===57));
  }
});

test('all colors traverse exactly 51 outer cells, then enter only their own lane',()=>{
  const s=newState(COLORS.map((color,i)=>({id:String(i)})),0);
  for(const [i,p] of s.players.entries()) {
    assert.equal(p.color,COLORS[i]);
    const seen=new Set();
    for(let progress=0;progress<=50;progress++) {
      const global=(i*13+progress)%52;
      assert.equal(square(p,progress),global);
      seen.add(square(p,progress));
    }
    assert.equal(seen.size,51);
    assert.equal(square(p,50),(i*13+50)%52);
    assert.ok(!seen.has((i*13+51)%52));
    for(let progress=51;progress<=FINISH;progress++) assert.equal(square(p,progress),null);
    assert.equal(square(p,-1),null);
  }
  assert.deepEqual([...SAFE].sort((a,b)=>a-b),[0,8,13,21,26,34,39,47]);
});

test('every color needs six to enter; dice move the chosen token by exactly their value',()=>{
  for(const i of [0,1,2,3]) for(let die=1;die<=6;die++) {
    const base=newState(COLORS.map((_,j)=>({id:String(j)})),0);
    base.turn=i;
    const entered=roll(base,die);
    if(die!==6) { assert.equal(entered.turn,(i+1)%4); assert.deepEqual(base.players[i].tokens,[-1,-1,-1,-1]); }
    else { assert.deepEqual(legalMoves(entered),[0,1,2,3]); assert.equal(move(entered,2).players[i].tokens[2],0); }
    base.players[i].tokens[0]=10;
    const moved=move(roll(base,die),0);
    assert.equal(moved.players[i].tokens[0],10+die);
    assert.deepEqual(moved.players[i].tokens.slice(1),[-1,-1,-1]);
  }
});

test('each color turns into its lane from progress 50, requires exact home roll, and never captures in lane',()=>{
  for(const i of [0,1,2,3]) {
    const s=newState(COLORS.map((_,j)=>({id:String(j)})),0); s.turn=i;
    s.players[i].tokens[0]=50;
    const lane=move(roll(s,1));
    assert.equal(lane.players[i].tokens[0],51);
    assert.equal(square(lane.players[i],51),null);
    s.players[i].tokens=[56,FINISH,FINISH,FINISH];
    assert.equal(roll(s,2).turn,(i+1)%4);
    const won=move(roll(s,1));
    assert.equal(won.status,'completed'); assert.equal(won.winner,String(i));
    assert.deepEqual(won.players[i].tokens,[FINISH,FINISH,FINISH,FINISH]);
  }
});

test('every home-lane step obeys exact dice and finishing one token grants one extra roll',()=>{
  for(let i=0;i<4;i++) for(let progress=51;progress<=56;progress++) for(let die=1;die<=6;die++) {
    const s=newState(COLORS.map((_,j)=>({id:String(j)})),0);s.turn=i;
    s.players[i].tokens=[progress,FINISH,FINISH,FINISH];
    const rolled=roll(s,die);
    if(progress+die>FINISH) {
      assert.equal(rolled.turn,(i+1)%4);
      assert.equal(rolled.players[i].tokens[0],progress);
    } else {
      assert.ok(legalMoves(rolled).includes(0));
      const moved=move(rolled);
      assert.equal(moved.players[i].tokens[0],progress+die);
      assert.equal(moved.status,progress+die===FINISH?'completed':'active');
      if(progress+die<FINISH) assert.equal(moved.turn,die===6?i:(i+1)%4);
    }
  }
  const s=newState(players,0);s.players[0].tokens=[56,10,FINISH,FINISH];
  const arrived=move(roll(s,1));
  assert.equal(arrived.status,'active');assert.equal(arrived.turn,0);
  assert.equal(arrived.phase,'roll');
});

test('two-player red/yellow and four-player turns follow seat order without blockades',()=>{
  for(const count of [2,4]) {
    let s=newState(Array.from({length:count},(_,i)=>({id:String(i)})),0);
    for(let i=0;i<count;i++) {
      assert.equal(s.turn,i);
      s=roll(s,1);
      assert.equal(s.turn,(i+1)%count);
    }
    s.players[0].tokens=[4,5,-1,-1];
    s=move(roll(s,2));
    assert.deepEqual(s.players[0].tokens.slice(0,2),[6,5]);
  }
});

test('unsafe captures all opponents on landing cell, while every safe cell protects them',()=>{
  for(let attacker=0;attacker<4;attacker++) for(let defender=0;defender<4;defender++) {
    if(attacker===defender) continue;
    for(const [target,shouldCapture] of [[7,true],[8,false],[0,false],[21,false]]) {
      const s=newState(COLORS.map((_,j)=>({id:String(j)})),0);s.turn=attacker;
      const from=(target-attacker*13+52)%52;
      const victim=(target-defender*13+52)%52;
      // Choose a safe target reachable in one step without wrapping into a lane.
      if(from<1 || from>50 || victim>50) continue;
      s.players[attacker].tokens[0]=from-1;
      s.players[defender].tokens[0]=victim;
      s.players[defender].tokens[1]=victim;
      const after=move(roll(s,1));
      assert.equal(after.players[attacker].tokens[0],from);
      assert.equal(after.players[defender].tokens[0],shouldCapture?-1:victim);
      assert.equal(after.players[defender].tokens[1],shouldCapture?-1:victim);
      assert.equal(after.turn,shouldCapture?attacker:(attacker+1)%4);
    }
  }
});

test('all eight safe squares protect pieces and all reachable unsafe squares allow capture',()=>{
  const group=COLORS.map((_,i)=>({id:String(i)}));
  for(let target=0;target<52;target++) {
    const attacker=Array.from({length:4},(_,i)=>i).find(i=>{
      const p=(target-i*13+52)%52;return p>=1&&p<=50;
    });
    const defender=Array.from({length:4},(_,i)=>i).find(i=>i!==attacker&&(target-i*13+52)%52<=50);
    assert.notEqual(attacker,undefined);assert.notEqual(defender,undefined);
    const attackProgress=(target-attacker*13+52)%52;
    const defendProgress=(target-defender*13+52)%52;
    const s=newState(group,0);s.turn=attacker;
    s.players[attacker].tokens=[attackProgress-1,attackProgress,-1,-1];
    s.players[defender].tokens=[defendProgress,-1,-1,-1];
    const after=move(roll(s,1));
    assert.equal(after.players[attacker].tokens[0],attackProgress);
    assert.equal(after.players[attacker].tokens[1],attackProgress);
    assert.equal(after.players[defender].tokens[0],SAFE.has(target)?defendProgress:-1,`global ${target}`);
    assert.equal(after.turn,SAFE.has(target)?(attacker+1)%4:attacker);
  }
});

test('legal moves preserve player choice and cannot be duplicated, forged or made out of turn',()=>{
  const s=newState(players,0);s.players[0].tokens=[2,50,56,FINISH];
  const rolled=roll(s,3);
  assert.deepEqual(legalMoves(rolled),[0,1]);
  assert.throws(()=>act(rolled,'a',{type:'move',token:2},2));
  assert.throws(()=>act(rolled,'b',{type:'move',token:0},2));
  const chosen=act(rolled,'a',{type:'move',token:1},2);
  assert.deepEqual(chosen.players[0].tokens,[2,53,56,FINISH]);
  assert.throws(()=>act(chosen,'a',{type:'move',token:1},3));
  assert.deepEqual(s.players[0].tokens,[2,50,56,FINISH]);
  const noMove=newState(players,0);noMove.players[0].tokens=[56,FINISH,FINISH,FINISH];
  assert.equal(roll(noMove,2).turn,1);
  assert.deepEqual(legalMoves(roll(noMove,1)),[0]);
});

test('third six discards only that roll; other bonuses and elimination follow documented turn order',()=>{
  let s=newState(COLORS.map((_,i)=>({id:String(i)})),0);
  s=move(roll(s,6));s=move(roll(s,6));
  const before=structuredClone(s.players[0].tokens);
  s=roll(s,6);
  assert.equal(s.turn,1);assert.deepEqual(s.players[0].tokens,before);
  assert.equal(s.sixes,0);assert.equal(s.phase,'roll');
  s=act(s,'2',{type:'forfeit'},2);
  assert.equal(s.turn,1);
  s=roll(s,1);assert.equal(s.turn,3);
  s=act(s,'3',{type:'forfeit'},3);
  assert.equal(s.turn,0);assert.equal(s.status,'active');
});

test('deterministic legal bot actions complete full two- and four-player matches',()=>{
  for(const count of [2,4]) {
    let s=newState(Array.from({length:count},(_,i)=>({id:`bot:${i}`})),0);
    let seed=42;
    const die=()=>{seed=(seed*1664525+1013904223)>>>0;return seed%6+1;};
    for(let step=1;s.status==='active'&&step<30000;step++) {
      const actor=s.players[s.turn].id;
      const action=botAction(s);
      if(action.type==='move') assert.ok(legalMoves(s).includes(action.token));
      s=act(s,actor,action,step,die);
      assert.equal(s.revision,step);
      for(const p of s.players) assert.ok(p.tokens.every(t=>Number.isInteger(t)&&t>=-1&&t<=FINISH));
    }
    assert.equal(s.status,'completed');
    assert.ok(s.players.find(p=>p.id===s.winner).tokens.every(t=>t===FINISH));
  }
});
