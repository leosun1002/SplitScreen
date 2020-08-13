//
//  ViewController.m
//  GLSL_Test
//
//  Created by leosun on 2020/7/29.
//  Copyright © 2020 leosun. All rights reserved.
//

#import "ViewController.h"
#import <GLKit/GLKit.h>
#import "FilterBar.h"

typedef struct {
    GLKVector3 positionCoord;//(X,Y,Z)
    GLKVector2 textureCoord;//(U,V)
} SenceVertex;

@interface ViewController ()<FilterBarDelegate>

@property(nonatomic,assign) SenceVertex *vertices;
@property(nonatomic,strong) EAGLContext *context;
//刷新屏幕
@property(nonatomic,strong) CADisplayLink *displayLink;
@property(nonatomic,assign) NSTimeInterval startTimeInterval;
//着色器程序
@property(nonatomic,assign) GLuint program;
//顶点缓存
@property(nonatomic,assign) GLuint vertexBuffer;
//纹理Id
@property (nonatomic, assign) GLuint textureID;

@end

@implementation ViewController

//释放
- (void)dealloc {
    //1.上下文释放
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    //顶点缓存区释放
    if (_vertexBuffer) {
        glDeleteBuffers(1, &_vertexBuffer);
        _vertexBuffer = 0;
    }
    //顶点数组释放
    if (_vertices) {
        free(_vertices);
        _vertices = nil;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // 移除 displayLink
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    self.view.backgroundColor = [UIColor blackColor];
    //创建滤镜工具栏
    [self setUpFilterbar];
    //滤镜处理初始化
    [self filterInit];
    //开始一个滤镜动画
    [self startFilerAnimation];
}

-(void)setUpFilterbar{
    CGFloat filterBarWidth = [UIScreen mainScreen].bounds.size.width;
    GLfloat filterBarHeight = 80;
    CGFloat filterBarY = [UIScreen mainScreen] .bounds.size.height - filterBarHeight;
    FilterBar *filterBar = [[FilterBar alloc] initWithFrame:CGRectMake(0, filterBarY, filterBarWidth, filterBarHeight)];
    filterBar.delegate = self;
    [self.view addSubview:filterBar];
    
    NSArray *dataSource = @[@"无",@"分屏_2",@"分屏_3",@"分屏_4",@"分屏_6",@"分屏_9"];
    filterBar.itemList = dataSource;
}

-(void)startFilerAnimation{
    //判断dispalyLink是否为空
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
    
    self.startTimeInterval = 0;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(timeAction)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

-(void)timeAction{
    //DisplayLink 的当前时间撮
    if (self.startTimeInterval == 0) {
        self.startTimeInterval = self.displayLink.timestamp;
    }
    //使用program(有可能切换到其他特效)
    glUseProgram(self.program);
    //绑定buffer
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);
    
    // 传入时间
    CGFloat currentTime = self.displayLink.timestamp - self.startTimeInterval;
    GLuint time = glGetUniformLocation(self.program, "Time");
    glUniform1f(time, currentTime);
    
    // 清除画布
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(1, 1, 1, 1);
    
    // 重绘
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    //渲染到屏幕上
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

-(void)filterInit{
    //初始化上下文
    self.context = [[EAGLContext alloc] initWithAPI:(kEAGLRenderingAPIOpenGLES3)];
    //设置当前上下文
    [EAGLContext setCurrentContext:self.context];

    //初始化顶点数组内存空间
    self.vertices = malloc(sizeof(SenceVertex) * 4);

    //初始化顶点(0,1,2,3)的顶点坐标以及纹理坐标
    self.vertices[0] = (SenceVertex){{-1, 1, 0}, {0, 1}};
    self.vertices[1] = (SenceVertex){{-1, -1, 0}, {0, 0}};
    self.vertices[2] = (SenceVertex){{1, 1, 0}, {1, 1}};
    self.vertices[3] = (SenceVertex){{1, -1, 0}, {1, 0}};

    //创建图层
    CAEAGLLayer *layer = [[CAEAGLLayer alloc] init];
    //设置图层frame
    layer.frame = CGRectMake(0, 100, self.view.frame.size.width, self.view.frame.size.height - 80 - 100 - 20);
    //设置图层scale
    layer.contentsScale = [UIScreen mainScreen].scale;
    //给view添加layer
    [self.view.layer addSublayer:layer];
    
    //绑定渲染缓冲区
    [self bindRenderLayer:layer];
    
    //处理图片路径
    //6.获取处理的图片路径
    NSString *imagePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"jay.jpg"];
    //读取图片
    UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
    //将JPG图片转换成纹理图片
    GLuint textureID = [self createTextureWithImage:image];
    
    self.textureID = textureID;  // 将纹理 ID 保存，方便后面切换滤镜的时候重用

    //设置视口
    glViewport(0, 0, self.drawableWidth, self.drawableHeight);
    
    //设置顶点缓冲区
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(SenceVertex) * 4, self.vertices, GL_STATIC_DRAW);
    
    //设置默认着色器
    [self setupNormalShaderProgram];

    //10.将顶点缓存保存，退出时才释放
    self.vertexBuffer = vertexBuffer;
}

//绑定渲染缓冲区
- (void)bindRenderLayer:(CALayer <EAGLDrawable> *)layer {
    //渲染缓冲区
    GLuint renderBuffer;
    GLuint frameBuffer;
    
    //获取帧渲染缓存区名称,绑定渲染缓存区以及将渲染缓存区与layer建立连接
    glGenRenderbuffers(1, &renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
    
     //获取帧缓存区名称,绑定帧缓存区以及将渲染缓存区附着到帧缓存区上
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderBuffer);
}

//将图片转换成纹理
-(GLuint)createTextureWithImage:(UIImage *)image{
    //将图片转换成GGImageRef
    CGImageRef imgRef = [image CGImage];
    if (!imgRef) {
        NSLog(@"图片转换失败");
        exit(1);
    }
    //读取图片大小
    size_t width = CGImageGetWidth(imgRef);
    size_t height = CGImageGetHeight(imgRef);
    //获取图片的rect
    CGRect rect = CGRectMake(0, 0, width, height);

    //获取图片的颜色空间
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(imgRef);
    //获取图片字节数
    void *imageData = malloc(width * height * 4);
    //4.创建上下文
    /*
     参数1：data,指向要渲染的绘制图像的内存地址
     参数2：width,bitmap的宽度，单位为像素
     参数3：height,bitmap的高度，单位为像素
     参数4：bitPerComponent,内存中像素的每个组件的位数，比如32位RGBA，就设置为8
     参数5：bytesPerRow,bitmap的没一行的内存所占的比特数
     参数6：colorSpace,bitmap上使用的颜色空间  kCGImageAlphaPremultipliedLast：RGBA
     */
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    //将图片翻转过来(图片默认是倒置的)
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGColorSpaceRelease(colorSpace);
    CGContextClearRect(context, rect);

    //对图片进行重新绘制
    CGContextDrawImage(context, rect, imgRef);
    
    //设置图片纹理属性
    GLuint textureID;
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    
    //6.载入纹理2D数据
    /*
     参数1：纹理模式，GL_TEXTURE_1D、GL_TEXTURE_2D、GL_TEXTURE_3D
     参数2：加载的层次，一般设置为0
     参数3：纹理的颜色值GL_RGBA
     参数4：宽
     参数5：高
     参数6：border，边界宽度
     参数7：format
     参数8：type
     参数9：纹理数据
     */
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (float)width, (float)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    
    //设置纹理属性
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    //绑定纹理
    glBindTexture(GL_TEXTURE_2D, textureID);
    
    //释放context和 imageData
    CGContextRelease(context);
    free(imageData);
    return textureID;
}

//获取渲染缓存区的宽
- (GLint)drawableWidth {
    GLint backingWidth;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    return backingWidth;
}
//获取渲染缓存区的高
- (GLint)drawableHeight {
    GLint backingHeight;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    return backingHeight;
}

#pragma -mark Shader
-(void)setupNormalShaderProgram{
    [self setupShaderProgramWithName:@"Normal"];
}

-(void)setupSplitScreen_2ShaderProgram{
    [self setupShaderProgramWithName:@"SplitScreen_2"];
}

-(void)setupSplitScreen_3ShaderProgram{
    [self setupShaderProgramWithName:@"SplitScreen_3"];
}

-(void)setupSplitScreen_4ShaderProgram{
    [self setupShaderProgramWithName:@"SplitScreen_4"];
}

-(void)setupSplitScreen_6ShaderProgram{
    [self setupShaderProgramWithName:@"SplitScreen_6"];
}

-(void)setupSplitScreen_9ShaderProgram{
    [self setupShaderProgramWithName:@"SplitScreen_9"];
}

-(void)setupShaderProgramWithName:(NSString *)name{
    //获取着色器程序
    GLuint program = [self programWithShaderName:name];
    //使用程序
    glUseProgram(program);
    //获取Position,Texture,TextureCoords 的索引位置
    GLuint positionSlot = glGetAttribLocation(program, "Position");
    GLuint textureSlot = glGetAttribLocation(program, "Texture");
    GLuint TextureCoordsSlot = glGetAttribLocation(program, "TextureCoords");
    //激活纹理，绑定纹理Id
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureID);

    //设置纹理采样
    glUniform1f(textureSlot, 0);
    
    //打开positionSlot 属性并且传递数据到positionSlot中(顶点坐标)
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(SenceVertex),NULL + offsetof(SenceVertex, positionCoord));
    
    //打开TextureCoordsSlot 属性并且传递数据到positionSlot中(顶点坐标)
    glEnableVertexAttribArray(TextureCoordsSlot);
    glVertexAttribPointer(TextureCoordsSlot, 2, GL_FLOAT, GL_FALSE, sizeof(SenceVertex),NULL + offsetof(SenceVertex, textureCoord));

    //保存progrm
    self.program = program;
}

-(GLuint)programWithShaderName:(NSString *)name{
    //编译顶点、片元着色器
    GLuint vertexShader =[self compileShaderWithName:name type:GL_VERTEX_SHADER];
    GLuint fragmentShader =[self compileShaderWithName:name type:GL_FRAGMENT_SHADER];
    //将顶点、片元附着到program
    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    //连接Program
    glLinkProgram(program);
    GLint linkSuccess;
    glGetProgramiv(program, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(program, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"program链接失败：%@", messageString);
        exit(1);
    }
    return program;
}

-(GLuint)compileShaderWithName:(NSString *)name type:(GLenum)type{
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:type == GL_VERTEX_SHADER?@"vsh":@"fsh"];
    NSError *error;
    NSString *shaderString = [NSString stringWithContentsOfFile:path encoding:(NSUTF8StringEncoding) error:&error];
    if (!shaderString) {
        NSAssert(NO, @"读取Shader失败");
        exit(1);
    }
    //创建Shader
    //2. 创建shader->根据shaderType
    GLuint shader = glCreateShader(type);
    
    //3.获取shader source
    const char *shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = (int)[shaderString length];
    glShaderSource(shader, 1, &shaderStringUTF8, &shaderStringLength);
    
    //4.编译shader
    glCompileShader(shader);
    
    //查看编译是否f成功
    GLint compileSuccess;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar message[256];
        glGetShaderInfoLog(shader, sizeof(message), 0, &message[0]);
        NSString *messageString = [NSString stringWithUTF8String:message];
        NSAssert(NO, @"shader编译失败：%@", messageString);
        exit(1);
    }
    return shader;
}

#pragma -mark FilterBarDelegate
- (void)filterBar:(FilterBar *)filterBar didScrollToIndex:(NSUInteger)index {
    if (index == 0) {
        [self setupNormalShaderProgram];
    }else if (index == 1){
        [self setupSplitScreen_2ShaderProgram];
    }else if (index == 2){
        [self setupSplitScreen_3ShaderProgram];
    }else if (index == 3){
        [self setupSplitScreen_4ShaderProgram];
    }else if (index == 4){
        [self setupSplitScreen_6ShaderProgram];
    }else if (index == 5){
        [self setupSplitScreen_9ShaderProgram];
    }
    [self startFilerAnimation];
}


@end
