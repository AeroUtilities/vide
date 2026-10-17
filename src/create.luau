--* [[----------< global guards >----------]]

local typeof = if Instance then typeof else require "../test/mock".typeof :: never
local Instance = if Instance then Instance else require "../test/mock".Instance :: never


--* [[----------< modules >----------]]

local defaults = require "./defaults"
local apply = require "./apply"
local flags = require "./flags"


--* [[----------< types >----------]]

export type Instances = {
    -- world objects
    Part: Part,

    -- containers
    Folder: Folder,
    Configuration: Configuration,

    -- layer collectors
    ScreenGui: ScreenGui,
    SurfaceGui: SurfaceGui,
    BillboardGui: BillboardGui,

    -- ui objects
    Frame: Frame,
    CanvasGroup: CanvasGroup,
    ImageButton: ImageButton,
    ImageLabel: ImageLabel,
    ScrollingFrame: ScrollingFrame,
    TextBox: TextBox,
    TextButton: TextButton,
    TextLabel: TextLabel,
    VideoFrame: VideoFrame,
    Path2D: Path2D,

    -- ui components
    UIAspectRatioConstraint: UIAspectRatioConstraint,
    UICorner: UICorner,
    UIGradient: UIGradient,
    UISizeConstraint: UISizeConstraint,
    UITextSizeConstraint: UITextSizeConstraint,
    UIScale: UIScale,
    UIPadding: UIPadding,
    UIStroke: UIStroke,
    UIFlexItem: UIFlexItem,
    UIShadow: UIShadow,
    UIDragDetector: UIDragDetector,

    -- ui layouts
    UIGridLayout: UIGridLayout,
    UIListLayout: UIListLayout,
    UIPageLayout: UIPageLayout,
    UITableLayout: UITableLayout,

    -- viewports / world ui
    ViewportFrame: ViewportFrame,
    Camera: Camera,
    WorldModel: WorldModel,

    -- interaction
    ProximityPrompt: ProximityPrompt,

    -- value objs
    BoolValue: BoolValue,
    IntValue: IntValue,
    NumberValue: NumberValue,
    StringValue: StringValue,
    ObjectValue: ObjectValue,
    Color3Value: Color3Value,
    Vector3Value: Vector3Value,
    CFrameValue: CFrameValue,
}

type PropertyTable = { [unknown]: unknown }
type Constructor = (PropertyTable) -> Instance
type Create = <Name>(Name|keyof<Instances>|"") -> (Properties<index<Instances, Name>>) -> index<Instances, Name>


--* [[----------< type function >----------]]

-- builds the table type accepted by a constructor for the given instance type
-- plain quotes are used in here since type functions run in a restricted environment
export type function Properties(instance: type?)
    local properties = types.newtable()

    while instance do
        for name, property in instance:properties() do
            local connector = property.read 
                and property.read.tag == "table" 
                and property.read:readproperty(types.singleton("Connect"))
            ;

            if connector then
                local params = connector:parameters().head
                if not params then 
                    continue
                end

                local listener = params[2]
                if not listener then 
                    continue
                end

                properties:setproperty(name, types.optional(listener))
            elseif property.write then
                -- writable properties accept the value itself or a function that returns the value
                properties:setproperty(name, types.optional(types.unionof(
                    property.write,
                    types.newfunction({}, { head = { property.write } })
                )))
            end
        end

        instance = instance:readparent()
    end

    -- number keys hold children, actions and nested property tables
    properties:setindexer(types.number, types.any)

    return properties
end


--* [[----------< state >----------]]

-- constructors for class names are created once and reused
local constructor_cache: { [string]: Constructor } = {}


--* [[----------< helper functions >----------]]

local function apply_defaults(instance: Instance, class: string)
    if not flags.defaults then 
        return 
    end

    local default = defaults[class]
    if not default then
        return
    end

    local target = instance :: any
    for property, value in default do
        target[property] = value
    end
end



local function create_constructor_class(class: string): Constructor
    return function(properties: PropertyTable): Instance
        local ok, instance: Instance = pcall(Instance.new, class :: any)
        if not ok then error(`invalid class name {class}`, 0) end

        apply_defaults(instance, class)
        return apply(instance, properties)
    end
end



local function get_class_constructor(class: string): Constructor
    local cached = constructor_cache[class]
    if cached then 
        return cached
    end

    local constructor = create_constructor_class(class)
    constructor_cache[class] = constructor

    return constructor
end


-- every call clones the template, so the template itself is never modified
local function create_clone_constructor(template: Instance): Constructor
    return function(properties)
        local clone = assert(template:Clone(), `attempt to clone a non-archivable instance`)

        return apply(clone, properties)
    end
end


--* [[----------< create >----------]]

-- todo: remove support for different overloads
local function create(class_or_instance: string|Instance, properties: PropertyTable?): unknown
    -- typeof() returns "Instance" (capital I) for instances; type() is enough for strings
    if type(class_or_instance) ~= "string" and typeof(class_or_instance) ~= "Instance" then
        error(`bad argument #1, expected string or instance, got {typeof(class_or_instance)}`, 0)
    end

    local constructor = if type(class_or_instance) == "string"
        then get_class_constructor(class_or_instance)
        else create_clone_constructor(class_or_instance)
    
    if properties then
        return constructor(properties)
    end

    return constructor
end



return create :: Create
