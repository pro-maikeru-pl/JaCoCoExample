package example;

import junit.framework.Assert;
import org.junit.Test;

public class HelloWorldUnitTest {
    
	@Test
    public void test() {
        new HelloWorld().coveredByUnitTest();
    }

    @Test
    public void shouldPass() {
        Assert.assertEquals(1, 1);
    }
	
}
