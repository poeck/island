//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "services"
import "ui"
import "views"
ShellRoot {
    WeatherService { id:service; expanded:true; requestCommand:["python3",Quickshell.env("ISLAND_WEATHER_FIXTURE")] }
    FloatingWindow {
        id:window;visible:true;title:"Island weather fixture";implicitWidth:1920;implicitHeight:1080;color:"#355363"
        Rectangle {
            id:body;x:(window.width-width)/2;y:28;width:Math.min(780,window.width-48);height:Math.min(540,window.height-52);radius:38;topLeftRadius:0;topRightRadius:0;color:"black"
            WeatherView { id:view;anchors.fill:parent;service:service;active:true }
        }
        InverseCorner {x:body.x-width;y:body.y;width:12;height:12}
        InverseCorner {x:body.x+body.width;y:body.y;width:12;height:12;mirrored:true}
    }
    IpcHandler {
        target:"weather-test"
        function state():string {return JSON.stringify({city:service.location.name,loaded:service.forecastData!==null,error:service.error,stale:service.stale,loading:service.loading,query:service.query,results:service.results,searched:service.searched,hourly:view.hourly,choosing:view.choosing,demo:service.demo});}
        function query(value:string):void {service.query=value;}
        function choose(value:string):void {service.choose({name:value,country:"Austria",latitude:value==="Graz"?47.07:48.2085,longitude:16.3721,timezone:"Europe/Vienna"});}
        function demo(value:bool):void {service.demo=value;}
        function geometry(name:string):string {
            function find(item) {if(item.objectName===name){const p=item.mapToItem(null,0,0);return {x:p.x,y:p.y,width:item.width,height:item.height,visible:item.visible,enabled:item.enabled,text:item.text};}for(const c of item.children||[]){const r=find(c);if(r)return r;}return null;}
            return JSON.stringify(find(window.contentItem));
        }
    }
}
