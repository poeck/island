//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "ui"
import "views"
ShellRoot {
    SystemService {
        id: service; polling: false; powerDevice: null
        powerProfiles.active: true
        snapshot: ({cpu:{name:"Test processor",threads:12,usage:24,temperature:42,load:[.4,.5,.6]},memory:{total:32*1024**3,used:16*1024**3,usage:50},gpus:[],network:{},disks:[],uptime:4200,os:"NixOS",kernel:"Linux"})
    }
    FloatingWindow {
        id: window; visible: true; title: "Island power fixture"; implicitWidth:1920;implicitHeight:1080;color:"#355363"
        Rectangle {
            id: body;x:(window.width-width)/2;y:28;width:Math.min(760,window.width-48);height:Math.min(window.height-52,view.preferredHeight)
            radius:38;topLeftRadius:0;topRightRadius:0;color:"black"
            SystemView {id:view;anchors.fill:parent;service:service;active:true}
        }
        InverseCorner {x:body.x-width;y:body.y;width:12;height:12}
        InverseCorner {x:body.x+body.width;y:body.y;width:12;height:12;mirrored:true}
    }
    IpcHandler {
        target:"power-test"
        function state(): string {return JSON.stringify({status:service.powerProfiles.status,busy:service.powerProfiles.busy,error:service.powerProfiles.error,notice:service.powerProfiles.notice});}
        function choose(profile:string):void {service.powerProfiles.select(profile);}
        function geometry(name:string):string {
            function find(item) {if(item.objectName===name){const p=item.mapToItem(null,0,0);return {x:p.x,y:p.y,width:item.width,height:item.height,visible:item.visible,enabled:item.enabled};}for(const c of item.children||[]){const r=find(c);if(r)return r;}return null;}
            return JSON.stringify(find(window.contentItem));
        }
    }
}
