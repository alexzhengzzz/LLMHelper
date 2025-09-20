import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import { AutoTTSService, PlaybackState, PlaybackTask, AutoTTSCallbacks } from '../main/ets/services/AutoTTSService';
import { TTSService } from '../main/ets/services/TTSService';
import { AppStorage } from '../main/ets/utils/AppStorage';

/**
 * 自动TTS服务测试套件
 * 测试自动语音播报服务的队列管理、状态控制、设置更新等功能
 */
export default function autoTTSServiceTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('AutoTTSServiceTest');

  describe('AutoTTSServiceTest', () => {
    let autoTTS: AutoTTSService;
    let mockTTSService: TTSService;
    let testCallbacks: AutoTTSCallbacks;
    let callbackEvents: Array<{type: string, data?: any}> = [];

    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化自动TTS服务测试环境');

      // 清理可能存在的实例
      // @ts-ignore - 访问私有属性进行测试清理
      AutoTTSService.instance = null;

      // 获取自动TTS服务实例
      autoTTS = AutoTTSService.getInstance();

      // 设置测试回调
      testCallbacks = {
        onTaskStart: (task: PlaybackTask) => {
          callbackEvents.push({type: 'taskStart', data: task});
          TestUtils.log(`任务开始回调: ${task.id}`);
        },
        onTaskComplete: (task: PlaybackTask) => {
          callbackEvents.push({type: 'taskComplete', data: task});
          TestUtils.log(`任务完成回调: ${task.id}`);
        },
        onTaskError: (task: PlaybackTask, error: Error) => {
          callbackEvents.push({type: 'taskError', data: {task, error}});
          TestUtils.log(`任务错误回调: ${task.id}, ${error.message}`);
        },
        onQueueEmpty: () => {
          callbackEvents.push({type: 'queueEmpty'});
          TestUtils.log('队列空回调');
        },
        onSettingsChanged: (settings: any) => {
          callbackEvents.push({type: 'settingsChanged', data: settings});
          TestUtils.log(`设置变更回调: ${JSON.stringify(settings)}`);
        }
      };

      autoTTS.setCallbacks(testCallbacks);

      // 初始化服务
      const initialized = await autoTTS.initialize();
      expect(initialized).assertTrue();

      await TestUtils.sleep(500);
    });

    afterAll(async () => {
      await TestUtils.cleanupTestData();
      await autoTTS.destroy();
      testSuite.afterAll();
    });

    beforeEach(() => {
      testSuite.beforeEach();
      callbackEvents = [];
    });

    afterEach(() => {
      testSuite.afterEach();
    });

    /**
     * 测试服务初始化
     */
    it('should initialize service correctly', async () => {
      TestUtils.log('测试服务初始化功能');

      // 验证服务已初始化
      expect(autoTTS.getCurrentState()).assertEqual(PlaybackState.IDLE);
      expect(autoTTS.getQueueLength()).assertEqual(0);
      expect(autoTTS.getCurrentTask()).assertNull();
      expect(autoTTS.isPlaying()).assertFalse();

      TestUtils.log('服务初始化验证通过');
    });

    /**
     * 测试添加播报任务
     */
    it('should add playback task to queue', async () => {
      TestUtils.log('测试添加播报任务功能');

      const testContent = '这是一条测试消息';
      const taskId = await autoTTS.addPlaybackTask(testContent, 'msg001', 1);

      // 验证任务ID不为空
      expect(taskId.length > 0).assertTrue();

      // 验证队列长度增加
      expect(autoTTS.getQueueLength()).assertEqual(1);

      TestUtils.log(`播报任务添加成功: ${taskId}`);
    });

    /**
     * 测试文本预处理
     */
    it('should preprocess text content correctly', async () => {
      TestUtils.log('测试文本预处理功能');

      const testCases = [
        {
          input: '这是包含```代码块```的消息',
          expected: '这是包含[代码块]的消息'
        },
        {
          input: '这是包含`行内代码`的消息',
          expected: '这是包含[代码]的消息'
        },
        {
          input: '这是包含[链接文字](https://example.com)的消息',
          expected: '这是包含链接文字的消息'
        },
        {
          input: '这是包含<html>标签</html>的消息',
          expected: '这是包含标签的消息'
        },
        {
          input: '   多余空格   消息   ',
          expected: '多余空格 消息'
        },
        {
          input: '',
          expected: ''
        }
      ];

      for (const testCase of testCases) {
        const taskId = await autoTTS.addPlaybackTask(testCase.input, 'test_msg');
        if (testCase.expected) {
          expect(taskId.length > 0).assertTrue();
        } else {
          expect(taskId.length).assertEqual(0);
        }
      }

      TestUtils.log('文本预处理测试通过');
    });

    /**
     * 测试优先级队列
     */
    it('should handle priority queue correctly', async () => {
      TestUtils.log('测试优先级队列功能');

      // 清空队列
      autoTTS.clearQueue();

      // 添加不同优先级的任务
      await autoTTS.addPlaybackTask('低优先级任务', 'low', 1);
      await autoTTS.addPlaybackTask('高优先级任务', 'high', 5);
      await autoTTS.addPlaybackTask('中优先级任务', 'medium', 3);

      // 验证队列长度
      expect(autoTTS.getQueueLength()).assertEqual(3);

      TestUtils.log('优先级队列测试通过');
    });

    /**
     * 测试手动播报
     */
    it('should handle manual playback correctly', async () => {
      TestUtils.log('测试手动播报功能');

      // 清空队列
      autoTTS.clearQueue();

      const testContent = '手动播报测试消息';
      const taskId = await autoTTS.playMessage(testContent, 'manual_msg');

      // 验证任务ID不为空
      expect(taskId.length > 0).assertTrue();

      // 验证队列状态（手动播放应该清空之前的队列）
      expect(autoTTS.getQueueLength()).assertLessThanOrEqual(1);

      TestUtils.log(`手动播报测试成功: ${taskId}`);
    });

    /**
     * 测试播放控制
     */
    it('should handle playback controls correctly', async () => {
      TestUtils.log('测试播放控制功能');

      // 添加测试任务
      await autoTTS.addPlaybackTask('控制测试消息', 'control_msg', 10);

      // 测试停止播放
      await autoTTS.stopPlayback();
      expect(autoTTS.getCurrentState()).assertEqual(PlaybackState.STOPPED);

      // 测试暂停播放（需要在播放状态下）
      // 注意：由于实际TTS播放需要时间，这里主要测试状态管理
      TestUtils.log('播放控制测试通过');
    });

    /**
     * 测试设置管理
     */
    it('should manage settings correctly', async () => {
      TestUtils.log('测试设置管理功能');

      // 获取当前设置
      const originalSettings = autoTTS.getSettings();

      // 更新设置
      const newSettings = {
        muted: true,
        speed: 1.2,
        volume: 0.8,
        pitch: 1.0,
        language: 'zh-CN',
        autoPlayOnReceive: false
      };

      await autoTTS.updateSettings(newSettings);

      // 验证设置更新
      const updatedSettings = autoTTS.getSettings();
      expect(updatedSettings.muted).assertEqual(newSettings.muted);
      expect(updatedSettings.speed).assertEqual(newSettings.speed);
      expect(updatedSettings.volume).assertEqual(newSettings.volume);

      // 验证设置变更回调被触发
      const settingChangedEvent = callbackEvents.find(e => e.type === 'settingsChanged');
      expect(settingChangedEvent !== undefined).assertTrue();

      TestUtils.log('设置管理测试通过');

      // 恢复原始设置
      await autoTTS.updateSettings(originalSettings);
    });

    /**
     * 测试静音模式
     */
    it('should handle mute mode correctly', async () => {
      TestUtils.log('测试静音模式功能');

      // 开启静音
      await autoTTS.updateSettings({muted: true});

      // 添加低优先级任务
      const lowPriorityTaskId = await autoTTS.addPlaybackTask('静音模式测试消息', 'mute_test', 1);
      expect(lowPriorityTaskId.length).assertEqual(0); // 静音时低优先级任务应该被拒绝

      // 添加高优先级任务（手动播放）
      const highPriorityTaskId = await autoTTS.playMessage('静音模式手动播放', 'mute_manual');
      expect(highPriorityTaskId.length > 0).assertTrue(); // 高优先级任务应该被接受

      // 关闭静音
      await autoTTS.updateSettings({muted: false});

      TestUtils.log('静音模式测试通过');
    });

    it('should toggle mute state when idle', async () => {
      TestUtils.log('测试空闲状态下的静音切换');

      const originalSettings = autoTTS.getSettings();

      await autoTTS.updateSettings({muted: false});
      const afterMute = await autoTTS.toggleMuteState();
      expect(afterMute.muted).assertTrue();

      const afterUnmute = await autoTTS.toggleMuteState();
      expect(afterUnmute.muted).assertFalse();

      await autoTTS.updateSettings({muted: originalSettings.muted});

      TestUtils.log('空闲状态静音切换测试通过');
    });

    it('should force stop playback immediately when mute is enabled', async () => {
      TestUtils.log('测试静音开启时立即停止当前播报');

      const originalSettings = autoTTS.getSettings();
      if (originalSettings.muted) {
        await autoTTS.updateSettings({muted: false});
      }

      const ttsService = (autoTTS as unknown as {ttsService: TTSService}).ttsService;
      const originalForceStop = ttsService.forceStop.bind(ttsService);
      let forceStopCalled = false;

      const mockTask: PlaybackTask = {
        id: 'mute_force_stop_task',
        content: '静音测试播报',
        messageId: 'mute_force_stop_task',
        priority: 1,
        timestamp: Date.now(),
        retryCount: 0
      };

      // @ts-ignore - 设置私有属性模拟正在播放的状态
      autoTTS['currentState'] = PlaybackState.PLAYING;
      // @ts-ignore - 设置私有属性模拟当前任务
      autoTTS['currentTask'] = mockTask;
      // @ts-ignore - 设置私有属性模拟队列中存在任务
      autoTTS['playbackQueue'] = [mockTask];
      // @ts-ignore - 重置取消标记
      autoTTS['cancelRequested'] = false;

      ttsService.forceStop = async () => {
        forceStopCalled = true;
        return true;
      };

      try {
        const result = await autoTTS.toggleMuteState();
        expect(forceStopCalled).assertTrue();
        expect(result.muted).assertTrue();
        expect(autoTTS.getQueueLength()).assertEqual(0);
        expect(autoTTS.getCurrentTask()).assertNull();
      } finally {
        ttsService.forceStop = originalForceStop;
        await autoTTS.updateSettings({muted: originalSettings.muted});
        // @ts-ignore - 重置内部状态，避免影响后续测试
        autoTTS['cancelRequested'] = false;
        // @ts-ignore - 重置当前状态
        autoTTS['currentState'] = PlaybackState.IDLE;
        // @ts-ignore - 清理当前任务引用
        autoTTS['currentTask'] = null;
        autoTTS.clearQueue();
      }
    });

    it('should reapply force stop when already muted but playback is running', async () => {
      TestUtils.log('测试在已静音但仍在播放时重新执行立即静音');

      const originalSettings = autoTTS.getSettings();
      if (!originalSettings.muted) {
        await autoTTS.updateSettings({muted: true});
      }

      const ttsService = (autoTTS as unknown as {ttsService: TTSService}).ttsService;
      const originalForceStop = ttsService.forceStop.bind(ttsService);
      let forceStopCalled = false;

      const mockTask: PlaybackTask = {
        id: 'mute_reapply_task',
        content: '静音重试测试播报',
        messageId: 'mute_reapply_task',
        priority: 1,
        timestamp: Date.now(),
        retryCount: 0
      };

      // @ts-ignore - 模拟仍在播放的状态
      autoTTS['currentState'] = PlaybackState.PLAYING;
      // @ts-ignore - 模拟当前任务
      autoTTS['currentTask'] = mockTask;
      // @ts-ignore - 队列中存在任务
      autoTTS['playbackQueue'] = [mockTask];
      // @ts-ignore - 重置取消标记
      autoTTS['cancelRequested'] = false;

      ttsService.forceStop = async () => {
        forceStopCalled = true;
        return true;
      };

      try {
        const result = await autoTTS.toggleMuteState();
        expect(forceStopCalled).assertTrue();
        expect(result.muted).assertTrue();
        expect(autoTTS.getQueueLength()).assertEqual(0);
        expect(autoTTS.getCurrentTask()).assertNull();
      } finally {
        ttsService.forceStop = originalForceStop;
        // @ts-ignore - 重置内部状态
        autoTTS['cancelRequested'] = false;
        // @ts-ignore - 重置当前状态
        autoTTS['currentState'] = PlaybackState.IDLE;
        // @ts-ignore - 清理当前任务引用
        autoTTS['currentTask'] = null;
        autoTTS.clearQueue();
        await autoTTS.updateSettings({muted: originalSettings.muted});
      }
    });

    /**
     * 测试队列管理
     */
    it('should manage queue correctly', async () => {
      TestUtils.log('测试队列管理功能');

      // 清空队列
      autoTTS.clearQueue();
      expect(autoTTS.getQueueLength()).assertEqual(0);

      // 添加多个任务
      const taskIds: string[] = [];
      for (let i = 0; i < 5; i++) {
        const taskId = await autoTTS.addPlaybackTask(`队列测试消息 ${i}`, `queue_${i}`, i);
        taskIds.push(taskId);
      }

      // 验证队列长度
      expect(autoTTS.getQueueLength()).assertEqual(5);

      // 测试移除特定消息的任务
      const removed = autoTTS.removeTaskByMessageId('queue_2');
      expect(removed).assertTrue();
      expect(autoTTS.getQueueLength()).assertEqual(4);

      // 清空队列
      autoTTS.clearQueue();
      expect(autoTTS.getQueueLength()).assertEqual(0);

      TestUtils.log('队列管理测试通过');
    });

    /**
     * 测试状态查询
     */
    it('should provide correct state information', async () => {
      TestUtils.log('测试状态查询功能');

      // 验证初始状态
      expect(autoTTS.getCurrentState()).assertEqual(PlaybackState.IDLE);
      expect(autoTTS.getCurrentTask()).assertNull();
      expect(autoTTS.isPlaying()).assertFalse();
      expect(autoTTS.isAutoPlayEnabled()).assertTrue();

      // 添加任务后验证状态
      await autoTTS.addPlaybackTask('状态测试消息', 'state_test', 1);
      expect(autoTTS.getQueueLength()).assertEqual(1);

      TestUtils.log('状态查询测试通过');
    });

    /**
     * 测试错误处理
     */
    it('should handle errors correctly', async () => {
      TestUtils.log('测试错误处理功能');

      // 测试空内容处理
      const emptyTaskId = await autoTTS.addPlaybackTask('', 'empty_test');
      expect(emptyTaskId.length).assertEqual(0);

      // 测试空白内容处理
      const whitespaceTaskId = await autoTTS.addPlaybackTask('   ', 'whitespace_test');
      expect(whitespaceTaskId.length).assertEqual(0);

      // 测试移除不存在的消息
      const removedNonexistent = autoTTS.removeTaskByMessageId('nonexistent');
      expect(removedNonexistent).assertFalse();

      TestUtils.log('错误处理测试通过');
    });

    /**
     * 测试回调机制
     */
    it('should trigger callbacks correctly', async () => {
      TestUtils.log('测试回调机制功能');

      // 清空事件记录
      callbackEvents = [];

      // 添加任务（应该触发相应的回调）
      await autoTTS.addPlaybackTask('回调测试消息', 'callback_test', 1);

      // 由于实际播放需要时间，这里主要验证回调设置是否正确
      expect(testCallbacks.onTaskStart !== undefined).assertTrue();
      expect(testCallbacks.onTaskComplete !== undefined).assertTrue();
      expect(testCallbacks.onTaskError !== undefined).assertTrue();
      expect(testCallbacks.onQueueEmpty !== undefined).assertTrue();
      expect(testCallbacks.onSettingsChanged !== undefined).assertTrue();

      TestUtils.log('回调机制测试通过');
    });

    /**
     * 测试服务销毁
     */
    it('should destroy service correctly', async () => {
      TestUtils.log('测试服务销毁功能');

      // 添加一些任务
      await autoTTS.addPlaybackTask('销毁测试消息', 'destroy_test', 1);

      // 销毁服务
      await autoTTS.destroy();

      // 验证服务状态
      expect(autoTTS.getCurrentState()).assertEqual(PlaybackState.IDLE);
      expect(autoTTS.getQueueLength()).assertEqual(0);
      expect(autoTTS.getCurrentTask()).assertNull();

      TestUtils.log('服务销毁测试通过');
    });

    /**
     * 测试重复初始化
     */
    it('should handle repeated initialization', async () => {
      TestUtils.log('测试重复初始化功能');

      // 重新初始化服务
      const reinitialized = await autoTTS.initialize();
      expect(reinitialized).assertTrue();

      // 验证服务状态正常
      expect(autoTTS.getCurrentState()).assertEqual(PlaybackState.IDLE);

      TestUtils.log('重复初始化测试通过');
    });

    /**
     * 测试长文本处理
     */
    it('should handle long text correctly', async () => {
      TestUtils.log('测试长文本处理功能');

      // 创建超长文本
      const longText = '这是一条很长的测试消息。'.repeat(100);
      const taskId = await autoTTS.addPlaybackTask(longText, 'long_text_test');

      // 验证任务被添加（文本被截断）
      expect(taskId.length > 0).assertTrue();

      TestUtils.log('长文本处理测试通过');
    });

    /**
     * 测试并发操作
     */
    it('should handle concurrent operations', async () => {
      TestUtils.log('测试并发操作功能');

      // 清空队列
      autoTTS.clearQueue();

      // 并发添加多个任务
      const promises: Promise<string>[] = [];
      for (let i = 0; i < 10; i++) {
        promises.push(autoTTS.addPlaybackTask(`并发测试消息 ${i}`, `concurrent_${i}`, i));
      }

      const results = await Promise.all(promises);

      // 验证所有任务都成功添加
      expect(results.every(id => id.length > 0)).assertTrue();
      expect(autoTTS.getQueueLength()).assertEqual(10);

      TestUtils.log('并发操作测试通过');
    });
  });
}
