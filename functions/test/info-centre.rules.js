const fs = require('node:fs');
const path = require('node:path');
const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
const {getDoc, doc, setDoc} = require('firebase/firestore');
const projectId = 'demo-league-hub-info';
let env;
let handlers;
let adminDb;
before(async () => {
  const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(':');
  env=await initializeTestEnvironment({projectId,firestore:{host,port:Number(port),rules:fs.readFileSync(path.join(__dirname,'../../firestore.rules'),'utf8')}});
  const admin=require('firebase-admin');
  if (!admin.apps.some((app) => app.name === '[DEFAULT]')) admin.initializeApp({projectId});
  const app=admin.initializeApp({projectId}, 'info-centre-tests');
  adminDb=app.firestore();
  const helpers=require('../lib/helpers');
  helpers.db=adminDb;
  handlers=require('../lib/infoCentre');
  await adminDb.doc('organizations/org').set({name:'Org'});
  await adminDb.doc('organizations/org/leagues/l').set({name:'League'});
  await adminDb.doc('organizations/org/leagues/l/hubs/h').set({name:'Hub'});
  await adminDb.doc('organizations/org/leagues/l/hubs/h/teams/t').set({name:'Team'});
  for (const role of ['platformOwner','superAdmin','managerAdmin','staff']) {
    await adminDb.doc(`users/${role}`).set({orgId:'org',role,isActive:true,hubIds:['h'],teamIds:['t']});
  }
});
after(async()=>{await env?.cleanup(); await adminDb?.terminate(); const admin=require('firebase-admin'); await Promise.all(admin.apps.map((app)=>app.delete()));});
const call=(name,uid,data)=>handlers[name].run({auth:{uid,token:{}},data:{orgId:'org',...data}});
let sectionId,entryId;
test('callables support scoped publishing, secrets, conflicts and manager isolation',async()=>{
  const base={leagueId:'l',hubId:'h',teamId:null,title:'Registration',status:'published',audience:'members',sortOrder:0};
  const section=await call('infoCentreUpsert','managerAdmin',{...base,type:'section',expectedRevision:0});
  sectionId=section.id;
  const entry=await call('infoCentreUpsert','managerAdmin',{...base,type:'entry',sectionId,teamId:'t',kind:'registration',url:'https://example.com/register',inviteCode:'example-code',password:'test-only-password',passwordAudience:'management',expectedRevision:0});
  entryId=entry.id;
  for (const role of ['platformOwner','superAdmin','managerAdmin','staff']) {
    const data=await call('infoCentreList',role,{});
    assert.equal(data.entries[0].id,entryId);
    assert.equal(data.entries[0].hasPassword,true);
    assert.equal(JSON.stringify(data).includes('test-only-password'),false);
    assert.equal(data.entries[0].canReveal,role!=='staff');
    if(role!=='staff') assert.equal((await call('infoCentreReveal',role,{id:entryId})).password,'test-only-password');
    const db=env.authenticatedContext(role).firestore();
    for (const collection of ['infoCentreSections','infoCentreEntries','infoCentreSecrets']) {
      await assertFails(getDoc(doc(db,`organizations/org/${collection}/${collection==='infoCentreSections'?sectionId:entryId}`)));
      await assertFails(setDoc(doc(db,`organizations/org/${collection}/injected`),{password:'injected'}));
    }
  }
  await assert.rejects(call('infoCentreReveal','staff',{id:entryId}),{code:'permission-denied'});
  await assert.rejects(call('infoCentreUpsert','staff',{...base,type:'section'}),{code:'permission-denied'});
  await assert.rejects(call('infoCentreUpsert','managerAdmin',{...base,hubId:null,type:'section'}),{code:'permission-denied'});
  await assert.rejects(call('infoCentreUpsert','managerAdmin',{...base,type:'section',id:sectionId,expectedRevision:0}),{code:'aborted'});
  await assert.rejects(call('infoCentreUpsert','managerAdmin',{...base,type:'entry',sectionId,kind:'link',url:'javascript:alert(1)'}),{code:'invalid-argument'});
  await adminDb.doc('users/foreign').set({orgId:'other',role:'superAdmin',isActive:true});
  await assert.rejects(call('infoCentreList','foreign',{}),{code:'permission-denied'});
  await adminDb.doc('users/staff').update({isActive:false});
  await assert.rejects(call('infoCentreList','staff',{}),{code:'permission-denied'});
  await adminDb.doc('users/managerAdmin').update({hubIds:[],teamIds:[]});
  await assert.rejects(call('infoCentreReveal','managerAdmin',{id:entryId}),{code:'permission-denied'});
  await adminDb.doc('users/managerAdmin').update({hubIds:['h'],teamIds:['t']});
  await adminDb.doc('organizations/org/leagues/l/hubs/h/teams/t').delete();
  for (const role of ['platformOwner','superAdmin','managerAdmin']) {
    assert.equal((await call('infoCentreList',role,{})).entries.length,0);
    await assert.rejects(call('infoCentreReveal',role,{id:entryId}),{code:'permission-denied'});
  }
  await adminDb.doc('organizations/org/leagues/l/hubs/h/teams/t').set({name:'Team'});
  await adminDb.doc('organizations/org/leagues/l/hubs/other').set({name:'Other hub'});
  await adminDb.doc(`organizations/org/infoCentreSections/${sectionId}`).update({hubId:'other'});
  await assert.rejects(call('infoCentreReveal','superAdmin',{id:entryId}),{code:'permission-denied'});
});
