// Copyright 2018-present 650 Industries. All rights reserved.

#import <ABI36_0_0EXSharing/ABI36_0_0EXSharingModule.h>
#import <ABI36_0_0UMCore/ABI36_0_0UMUtilitiesInterface.h>
#import <ABI36_0_0UMFileSystemInterface/ABI36_0_0UMFileSystemInterface.h>
#import <ABI36_0_0UMFileSystemInterface/ABI36_0_0UMFilePermissionModuleInterface.h>

@interface ABI36_0_0EXSharingModule ()

@property (nonatomic, weak) ABI36_0_0UMModuleRegistry *moduleRegistry;
@property (nonatomic, strong) UIDocumentInteractionController *documentInteractionController;

@property (nonatomic, strong) ABI36_0_0UMPromiseResolveBlock pendingResolver;

@end

@implementation ABI36_0_0EXSharingModule

ABI36_0_0UM_EXPORT_MODULE(ExpoSharing);

- (void)setModuleRegistry:(ABI36_0_0UMModuleRegistry *)moduleRegistry
{
  _moduleRegistry = moduleRegistry;
}

ABI36_0_0UM_EXPORT_METHOD_AS(shareAsync,
                    fileUrl:(NSString *)fileUrl
                    params:(NSDictionary *)params
                    resolve:(ABI36_0_0UMPromiseResolveBlock)resolve
                    reject:(ABI36_0_0UMPromiseRejectBlock)reject)
{
  if (_documentInteractionController) {
    NSString *errorMessage = @"Another item is being shared. Await the `shareAsync` request and then share the item again.";
    reject(@"E_SHARING_MUL", errorMessage, ABI36_0_0UMErrorWithMessage(errorMessage));
    return;
  }

  NSURL *url = [NSURL URLWithString:fileUrl];

  id<ABI36_0_0UMFilePermissionModuleInterface> filePermissionsModule = [_moduleRegistry getModuleImplementingProtocol:@protocol(ABI36_0_0UMFilePermissionModuleInterface)];
  if (filePermissionsModule && !([filePermissionsModule getPathPermissions:url.path] & ABI36_0_0UMFileSystemPermissionRead)) {
    NSString *errorMessage = @"You don't have access to provided file.";
    reject(@"E_SHARING_PERM", errorMessage, ABI36_0_0UMErrorWithMessage(errorMessage));
    return;
  }

  _documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:url];
  _documentInteractionController.delegate = self;
  _documentInteractionController.UTI = params[@"UTI"];

  UIViewController *viewController = [[_moduleRegistry getModuleImplementingProtocol:@protocol(ABI36_0_0UMUtilitiesInterface)] currentViewController];

  ABI36_0_0UM_WEAKIFY(self);
  dispatch_async(dispatch_get_main_queue(), ^{
    ABI36_0_0UM_ENSURE_STRONGIFY(self);
    UIView *rootView = [viewController view];
    if ([self.documentInteractionController presentOpenInMenuFromRect:CGRectZero inView:rootView animated:YES]) {
      self.pendingResolver = resolve;
    } else {
      reject(@"ERR_SHARING_UNSUPPORTED_TYPE", @"Could not share file since there were no apps registered for its type", nil);
      self.documentInteractionController = nil;
    }
  });
}

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller
{
  _pendingResolver(@{});
  _pendingResolver = nil;

  _documentInteractionController = nil;
}

@end
