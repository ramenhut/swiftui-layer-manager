
import SwiftUI
import Foundation

// The duration that layers take to animate in/out.
let kLayerAnimationDuration = 0.3
// The duration that toasts take to animate in/out.
let kToastAnimationDuration = 0.5
// The duration that toasts are visible by default.
let kDefaultToastVisibleDuration = 4.0

enum LayerEntryStyle {
    case Instant
    case Animated
}

enum LayerEntryDirection {
    case None
    case Top
    case Bottom
    case Left
    case Right
}

struct Layer {
    // Unique id assigned to the layer instance.
    var id = UUID()
    // Indicates whether the layer should be animated.
    var entryStyle : LayerEntryStyle = .Instant
    // Indicates the direction the layer should enter from.
    var entryDirection : LayerEntryDirection = .None
    // The maximum lifespan of the layer, in seconds. A zero
    // value indicates the layer has no maximum lifetime.
    var lifespan : Double = 0.0
    // Indicates whether the layer is modal (will fade out
    // background layers).
    var isModal = false
    // Indicates whether the layer is dismissable when tapped
    // outside of its primary view.
    var isDismissable = true
    // The generator responsible for producing the layer's view.
    var action: ((Layer) -> AnyView)
    // Computed transition based on entry properties.
    var transition: AnyTransition {
        if self.entryStyle == .Instant {
            return AnyTransition.identity
        }
        switch (self.entryDirection) {
            case .None: return AnyTransition.identity.combined(with:.opacity)
            case .Top: return AnyTransition.move(edge:.top)
            case .Bottom: return AnyTransition.move(edge:.bottom)
            case .Left: return AnyTransition.move(edge:.leading)
            case .Right: return AnyTransition.move(edge:.trailing)
        }
    }
}

class LayerManager : ObservableObject {
    // A generator that is responsible for producing layers.
    @Published var layers = [Layer]()
    // A single toast layer that has a limited lifespan. Toasts
    // are always animated onto the screen and have no completion
    // block associated with them.
    @Published var toast : Layer? = nil
    // A dictionary of anchor points that can be used to position layers.
    var anchors = [String:CGPoint]()
    // Stores the provided closure, which will be resolved by the parent view
    // and rendered above all other content.
    func push(
        // Should the layer become visible instantly, or with animation?
        entryStyle: LayerEntryStyle = .Instant,
        // Does the view slide in from off screen?
        entryDirection: LayerEntryDirection = .None,
        // Can the user interact with other parts of the screen while the view is visible?
        isModal: Bool = false,
        // Will the view disappear if the user taps outside of its bounds?
        isDismissable: Bool = true,
        // Should some action be taken once the view is finished loading/animating?
        completion:  (() -> Void)? = nil,
        // Defines the view hierarchy to present within this layer.
        layer : @escaping ((Layer) -> AnyView)) {
            
        switch (entryStyle) {
            case .Instant: layers.append(Layer(entryStyle: entryStyle, entryDirection: entryDirection, isModal:isModal, isDismissable:isDismissable, action: layer))
            case .Animated: withAnimation (.easeInOut(duration: kLayerAnimationDuration)) {
                layers.append(Layer(entryStyle: entryStyle, entryDirection: entryDirection, isModal:isModal, isDismissable:isDismissable, action: layer))
            }
        }
        
        if let postAppearCompletion = completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + kLayerAnimationDuration) {
                postAppearCompletion()
            }
        }
    }
    
    func toast(
        // Does the view slide in from off screen?
        entryDirection: LayerEntryDirection = .None,
        // Should the view automatically disappear after a certain timeout?
        lifespan: Double = kDefaultToastVisibleDuration,
        // Defines the view hierarchy to present within this layer.
        layer : @escaping ((Layer) -> AnyView)) {
        // Toasts must have a finite lifespan.
        assert(lifespan > 0.0)
            
        withAnimation (.easeInOut(duration: kToastAnimationDuration)) {
            toast = Layer(entryStyle: .Animated, entryDirection: entryDirection, lifespan: lifespan, action: layer)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + lifespan) { [weak self] in
            if let strongSelf = self {
                withAnimation (.easeInOut(duration: kToastAnimationDuration)) {
                    strongSelf.toast = nil
                }
            }
        }
    }
    
    func clearToast() {
        withAnimation (.easeInOut(duration: kToastAnimationDuration)) {
            self.toast = nil
        }
    }
                      
    func pop() {
        if layers.count == 0 { return }
        switch (layers[layers.count - 1].entryStyle) {
            case .Instant: layers.removeLast()
            case .Animated: _ = withAnimation (.easeInOut(duration: 0.3)) {layers.removeLast()}
        }
    }
    
    func pop(at: Int) {
        if layers.count == 0 || layers.count <= at { return }
        switch (layers[at].entryStyle) {
            case .Instant: layers.remove(at:at)
            case .Animated: _ = withAnimation (.easeInOut(duration: 0.3)) {layers.remove(at:at)}
        }
    }
    
    func pop(withId: UUID) {
        if layers.count == 0 { return }
        for index in 0..<layers.count {
            if layers[index].id == withId {
                pop(at:index)
                return
            }
        }
    }
    
    func popAll() {
        // Useful when we need to fully reset the hierarchy (e.g. on a logout).
        // Release in reverse order, in case there are reference dependencies.
        while layers.count > 0 {
            pop()
        }
        
        clearToast()
    }
}

struct LayerView<Presenting>: View where Presenting: View {
    // The parent view that's presenting our layer view.
    let presenting: () -> Presenting
    // Our Layer Manager.
    @StateObject var layerManager : LayerManager

    var body: some View {
        ZStack(alignment: .center) {
            // Render the parent view hierarchy.
            self.presenting()
            // Render each of our layers.
            ForEach (0..<layerManager.layers.count, id:\.self) { index in
                if (layerManager.layers[index].isModal) {
                    Rectangle()
                        .foregroundColor(Color.black.opacity(0.7))
                        .transition(AnyTransition.identity.combined(with:.opacity))
                        .zIndex(1)
                        .onTapGesture {
                            if (layerManager.layers[index].isDismissable) {
                                layerManager.pop(at:index)
                            }
                        }
                }
                layerManager.layers[index].action(layerManager.layers[index])
                    .transition(layerManager.layers[index].transition)
                    .zIndex(1)
            }
            
            if layerManager.toast != nil {
                layerManager.toast!.action(layerManager.toast!)
                    .transition(layerManager.toast!.transition)
                    .zIndex(1)
            }
        }
        .environmentObject(layerManager)
    }
}

extension View {
    func withLayerManager(layerManager: LayerManager) -> some View {
        LayerView(presenting: { self }, layerManager:layerManager)
    }
}
