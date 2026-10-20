import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { InfoCentreWorkspace } from './info-centre';
import type { AppUser } from '@/lib/types';
const { call }=vi.hoisted(()=>({call:vi.fn()}));
vi.mock('@/lib/callables',()=>({callAdmin:call}));
vi.mock('@/lib/firebase',()=>({demoMode:false}));
const user={id:'manager',email:'manager@example.com',displayName:'Manager',role:'managerAdmin',orgId:'org',isActive:true,hubIds:['h'],teamIds:[],leagueIds:['l']} as AppUser;
const data={structure:{leagues:[{id:'l',name:'League'}],hubs:[{id:'h',name:'Hub',leagueId:'l'}],teams:[]},sections:[],entries:[],policies:[]};
beforeEach(()=>{
 call.mockReset();call.mockResolvedValue(data);
 HTMLDialogElement.prototype.showModal=function(){this.setAttribute('open','');};
 HTMLDialogElement.prototype.close=function(){this.removeAttribute('open');};
});
afterEach(cleanup);
it('a manager creates a draft in the assigned hub through the scoped API',async()=>{
 render(<InfoCentreWorkspace currentUser={user} orgId="org" />);
 await screen.findByText('No sections yet');
 fireEvent.click(screen.getByRole('button',{name:'New section'}));
 fireEvent.change(screen.getByLabelText('Title'),{target:{value:'Useful links'}});
 fireEvent.click(screen.getByRole('button',{name:'Save'}));
 await waitFor(()=>expect(call).toHaveBeenCalledWith('infoCentreUpsert',expect.objectContaining({orgId:'org',title:'Useful links',hubId:'h',teamId:null,status:'draft',expectedRevision:0})));
});
it('a late previous-organization response cannot populate the new workspace',async()=>{
 let resolve!: (value:unknown)=>void;
 call.mockImplementationOnce(()=>new Promise((r)=>{resolve=r;}));
 const {rerender}=render(<InfoCentreWorkspace currentUser={user} orgId="org" />);
 rerender(<InfoCentreWorkspace currentUser={{...user,id:'other',orgId:'org2'}} orgId="org2" />);
 await screen.findByText('No sections yet');
 await act(async()=>resolve({...data,sections:[{id:'old',title:'Previous private section',leagueId:'l',hubId:'h',status:'published',audience:'management'}]}));
 expect(screen.queryByText('Previous private section')).toBeNull();
});
