
import SwiftUI

struct Scenario : Identifiable {
    var id = UUID()
    var title: String
    var direction: LayerEntryDirection
    var color: Color
}

let scenarios = [
    Scenario(title:"Blue", direction:.Bottom, color:Color.blue),
    Scenario(title:"Red", direction:.Right, color:Color.red),
    Scenario(title:"Green", direction:.Top, color:Color.green),
    Scenario(title:"Yellow", direction:.Left, color:Color.yellow),
]

struct StyledTextButton: View {
    // The text to render within the button.
    var text: String = ""
    // The action to perform when the button is tapped.
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button {
            if (action != nil) {
                action!()
            }
        } label: {
            Text(text)
                .frame(minWidth:150)
                .foregroundColor(Color.white)
                .padding()
                .background(Color.black)
                .cornerRadius(10.0)
        }
    }
}

struct ContentView: View {
    @StateObject var layerManager = LayerManager()
    var body: some View {
        VStack {
            ForEach(scenarios) { scenario in
                StyledTextButton(text:scenario.title) {
                    layerManager.push(entryStyle:.Animated, entryDirection:scenario.direction) { layer in
                        AnyView(
                            VStack (alignment: .center) {
                                Spacer()
                                StyledTextButton(text:"Close") { layerManager.pop() }
                                Spacer()
                            }
                            .frame(width:UIScreen.main.bounds.size.width)
                            .background(scenario.color)
                        )
                    }
                }.padding(.bottom, 20)
            }
            
            StyledTextButton(text:"Toast") {
                layerManager.toast(entryDirection:.Bottom, lifespan:2.0) { layer in
                    AnyView(
                        VStack {
                            Spacer()
                            Group {
                                Text("This is a toast")
                                    .foregroundColor(Color.white)
                                    .padding()
                            }
                            .frame(width:UIScreen.main.bounds.size.width, height:80)
                            .background(Color.purple)
                        }
                    )
                }
            }
        }
        .withLayerManager(layerManager: layerManager)
    }
}
