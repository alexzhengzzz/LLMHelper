import { describe, beforeAll, afterAll, beforeEach, afterEach, it, expect } from '@ohos/hypium';
import AppContext from '../../main/ets/utils/AppContext';

export default function AppContextTest() {
  describe('AppContextTest', () => {
    let originalContext: any;

    beforeAll(() => {
      // 保存原始context
      originalContext = (globalThis as any).AppContext;
    });

    afterAll(() => {
      // 恢复原始context
      (globalThis as any).AppContext = originalContext;
    });

    beforeEach(() => {
      // 重置AppContext
      AppContext.clear();
    });

    afterEach(() => {
      // 清理测试数据
      AppContext.clear();
    });

    it('should initialize with empty context', () => {
      const context = AppContext.getContext();
      expect(Object.keys(context).length).assertEqual(0);
    });

    it('should set and get values', () => {
      const testKey = 'testKey';
      const testValue = 'testValue';

      AppContext.set(testKey, testValue);
      const retrievedValue = AppContext.get(testKey);

      expect(retrievedValue).assertEqual(testValue);
    });

    it('should return undefined for non-existent keys', () => {
      const nonExistentKey = 'nonExistentKey';
      const retrievedValue = AppContext.get(nonExistentKey);

      expect(retrievedValue).assertEqual(undefined);
    });

    it('should provide default value for non-existent keys', () => {
      const nonExistentKey = 'nonExistentKey';
      const defaultValue = 'defaultValue';

      const retrievedValue = AppContext.get(nonExistentKey, defaultValue);

      expect(retrievedValue).assertEqual(defaultValue);
    });

    it('should check if key exists', () => {
      const testKey = 'testKey';

      expect(AppContext.has(testKey)).assertFalse();

      AppContext.set(testKey, 'testValue');
      expect(AppContext.has(testKey)).assertTrue();
    });

    it('should remove keys', () => {
      const testKey = 'testKey';
      const testValue = 'testValue';

      AppContext.set(testKey, testValue);
      expect(AppContext.has(testKey)).assertTrue();

      AppContext.remove(testKey);
      expect(AppContext.has(testKey)).assertFalse();
      expect(AppContext.get(testKey)).assertEqual(undefined);
    });

    it('should clear all keys', () => {
      AppContext.set('key1', 'value1');
      AppContext.set('key2', 'value2');
      AppContext.set('key3', 'value3');

      expect(AppContext.has('key1')).assertTrue();
      expect(AppContext.has('key2')).assertTrue();
      expect(AppContext.has('key3')).assertTrue();

      AppContext.clear();

      expect(AppContext.has('key1')).assertFalse();
      expect(AppContext.has('key2')).assertFalse();
      expect(AppContext.has('key3')).assertFalse();
    });

    it('should get all keys', () => {
      AppContext.set('key1', 'value1');
      AppContext.set('key2', 'value2');
      AppContext.set('key3', 'value3');

      const keys = AppContext.keys();
      expect(keys.length).assertEqual(3);
      expect(keys).toContain('key1');
      expect(keys).toContain('key2');
      expect(keys).toContain('key3');
    });

    it('should get all values', () => {
      AppContext.set('key1', 'value1');
      AppContext.set('key2', 'value2');
      AppContext.set('key3', 'value3');

      const values = AppContext.values();
      expect(values.length).assertEqual(3);
      expect(values).toContain('value1');
      expect(values).toContain('value2');
      expect(values).toContain('value3');
    });

    it('should get entire context', () => {
      const testData = {
        key1: 'value1',
        key2: 'value2',
        key3: 123
      };

      AppContext.set('key1', testData.key1);
      AppContext.set('key2', testData.key2);
      AppContext.set('key3', testData.key3);

      const context = AppContext.getContext();
      expect(context.key1).assertEqual(testData.key1);
      expect(context.key2).assertEqual(testData.key2);
      expect(context.key3).assertEqual(testData.key3);
    });

    it('should handle object values', () => {
      const testObject = {
        name: 'test',
        value: 123,
        nested: {
          inner: 'value'
        }
      };

      AppContext.set('objectKey', testObject);
      const retrievedObject = AppContext.get('objectKey');

      expect(retrievedObject).assertEqual(testObject);
    });

    it('should handle array values', () => {
      const testArray = [1, 2, 3, 'four', true];

      AppContext.set('arrayKey', testArray);
      const retrievedArray = AppContext.get('arrayKey');

      expect(retrievedArray.length).assertEqual(testArray.length);
      expect(retrievedArray[0]).assertEqual(testArray[0]);
      expect(retrievedArray[4]).assertEqual(testArray[4]);
    });

    it('should handle boolean values', () => {
      AppContext.set('boolKey', true);
      const retrievedValue = AppContext.get('boolKey');

      expect(retrievedValue).assertTrue();
    });

    it('should handle numeric values', () => {
      AppContext.set('numberKey', 42);
      const retrievedValue = AppContext.get('numberKey');

      expect(retrievedValue).assertEqual(42);
    });

    it('should handle null values', () => {
      AppContext.set('nullKey', null);
      const retrievedValue = AppContext.get('nullKey');

      expect(retrievedValue).assertEqual(null);
    });

    it('should update existing keys', () => {
      const testKey = 'testKey';
      const initialValue = 'initialValue';
      const updatedValue = 'updatedValue';

      AppContext.set(testKey, initialValue);
      expect(AppContext.get(testKey)).assertEqual(initialValue);

      AppContext.set(testKey, updatedValue);
      expect(AppContext.get(testKey)).assertEqual(updatedValue);
    });

    it('should remove non-existent keys gracefully', () => {
      const nonExistentKey = 'nonExistentKey';

      // 不应该抛出异常
      expect(() => {
        AppContext.remove(nonExistentKey);
      }).not.throw();
    });

    it('should handle empty context operations', () => {
      expect(AppContext.keys().length).assertEqual(0);
      expect(AppContext.values().length).assertEqual(0);
      expect(Object.keys(AppContext.getContext()).length).assertEqual(0);
    });

    it('should maintain context across instances', () => {
      const testKey = 'testKey';
      const testValue = 'testValue';

      AppContext.set(testKey, testValue);

      // 创建新的AppContext实例
      const newContext = AppContext;
      expect(newContext.get(testKey)).assertEqual(testValue);
    });
  });
}