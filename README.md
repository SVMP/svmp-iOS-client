# SVMP iOS Client
## Building

### Building the iOS Client

1. Checkout the SVMP client into a directory of your choice

    ```
    cd ${SVMP}
    git clone https://github.com/SVMP/svmp-iOS-client.git
    ```
2. Download the submodules

  ```
  git submodule update --init
  ```

3. Open up the Xcode project at svmp-iOS-client/ios-example/Svmp-iOS-Client.xcodeproj
4. Click the run button

### Building the Protobuf

1. Build protobuf

  Download protobuf 2.5.0 [here](https://code.google.com/p/protobuf/downloads/detail?name=protobuf-2.5.0.tar.gz&can=2&q=)

  ```
  tar zxf protobuf-2.5.0.tar.gz
  cd protobuf-2.5.0.tar.gz
  ./configure
  make
  make check
  make install
  ```

2. Download and build objective c plugin

  A plugin is used to allow objective c code to be generated. Clone the github
  project here: https://github.com/Packetdancer/protobuf-objc

  ```
  git clone https://github.com/Packetdancer/protobuf-objc.git
  ```

  Build the plugin

  ```
  cd protobuf-objc
  ./autogen.sh
  ./configure CXXFLAGS=-I/usr/local/include LDFLAGS=-L/usr/local/lib
  make
  make install
  ```

4. Download the SVMP Protobuf source

  ```
  git clone https://github.com/SVMP/svmp-protocol-def.git
  ```

5. Generate the objective c code

  ```
  protoc --plugin=/usr/local/bin/protoc-gen-objc --proto_path=<path/to>/svmp-protocol-def/ --objc_out=./ <path/to>/svmp-protocol-def/svmp.proto
  ```

  There should be an Svmp.pb.h and Svmp.pb.m file in the current directory now.

6. Fix the code

  Unfortunately, there is an error in the objective c code generated by the
  plugin.

  You must comment out a for loop within the storeInDictionary method within
  the Svmp.pb.m file.

  ```
  - (void) storeInDictionary:(NSMutableDictionary *)dictionary {
    if (self.hasAction) {
      [dictionary setObject: @(self.action) forKey: @"action"];
    }
    for (Intent_Tuple* element in self.extrasArray) {
      NSMutableDictionary *elementDictionary = [NSMutableDictionary dictionary];
      [element storeInDictionary:elementDictionary];
      [dictionary setObject:[NSDictionary dictionaryWithDictionary:elementDictionary] forKey: @"extras"];
    }
    if (self.hasData) {
      [dictionary setObject: self.data forKey: @"data"];
    }
    NSMutableArray * flagsArrayArray = [NSMutableArray new];
    NSUInteger flagsArrayCount=self.flagsArray.count;
    for(int i=0;i<flagsArrayCount;i++){
      [flagsArrayArray addObject: @([self.flagsArray int32AtIndex:i])];
    }
    [dictionary setObject: flagsArrayArray forKey: @"flags"];

    // V-- Comment this out otherwise you will get an error stating 'use of undeclared identifier 'output''
    /*for (NSString* element in self.categoriesArray) {
      [output appendFormat:@"%@%@: %@\n", indent, @"categories", element];
    }*/
    [self.unknownFields storeInDictionary:dictionary];
  }
  ```

7. Copy the generated protobuf code into the SVMP project

  ```
  cp Svmp.pb.* <path/to/svmp>/svmp-iOS-client/ios-example/AppRTCDemo/
  ```

### Building Webrtc

***TODO***

## License

Copyright (c) 2012-2014, The MITRE Corporation, All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
